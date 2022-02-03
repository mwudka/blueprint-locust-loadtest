provider "google" {
  project = var.gcp-project
  region  = var.region
  zone    = var.zone
}

data "google_compute_image" "ubuntu-2004-lts" {
  family  = "ubuntu-pro-2004-lts"
  project = "ubuntu-os-pro-cloud"
}

resource "google_compute_firewall" "default" {
  name    = "web-firewall"
  network = google_compute_network.network.self_link

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "5557"]
  }


  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

data "cloudinit_config" "cloudinit" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = <<EOT
apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io

write_files:
  - path: /locust/locustfile.py
    content: |
      from locust import HttpUser, task

      class HelloWorldUser(HttpUser):
        @task
        def hello_world(self):
          self.client.get("/")
EOT
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "startup.sh"
    content      = <<EOT
#!/usr/bin/env bash

set -eux

docker run -d --restart=always -p 80:8089 -p 5557:5557 -v /locust:/mnt/locust locustio/locust -f /mnt/locust/locustfile.py --master
EOT
  }
}


data "cloudinit_config" "cloudinit-worker" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = <<EOT
apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io

write_files:
  - path: /locust/locustfile.py
    content: |
      from locust import HttpUser, task

      class HelloWorldUser(HttpUser):
        @task
        def hello_world(self):
          self.client.get("/")
EOT
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "startup.sh"
    content      = <<EOT
#!/usr/bin/env bash

set -eux

docker run -d --restart=always -p 80:8089 -v /locust:/mnt/locust locustio/locust -f /mnt/locust/locustfile.py --worker --master-host ${local.private-ip}
EOT
  }
}


resource "google_compute_network" "network" {
  name                    = "${var.instance-name}-network"
  auto_create_subnetworks = true
}


resource "google_compute_instance" "vm_instance" {
  name         = "${var.instance-name}-leader"
  machine_type = var.instance-type

  tags = ["web"]

  allow_stopping_for_update = true

  metadata = {
    user-data = data.cloudinit_config.cloudinit.rendered
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu-2004-lts.self_link
    }
  }

  network_interface {
    network = google_compute_network.network.self_link

    access_config {
    }
  }
}

resource "google_compute_instance" "worker" {
  # TODO: Figure out how many requests a single instance can send.
  count        = max(ceil(var.requests-per-second / 100), 1)
  name         = "${var.instance-name}-worker-${count.index}"
  machine_type = var.instance-type

  tags = ["web"]

  allow_stopping_for_update = true

  metadata = {
    user-data = data.cloudinit_config.cloudinit-worker.rendered
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu-2004-lts.self_link
    }
  }

  network_interface {
    network = google_compute_network.network.self_link

    access_config {
    }
  }
}

locals {
  public-ip  = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
  private-ip = google_compute_instance.vm_instance.network_interface[0].network_ip
}
