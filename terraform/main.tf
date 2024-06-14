# Create Trigger for terraform plan ##


variable "enable_nifi_alert" {
    description = "Enable nifi metric alerts"
    type = string
    default = "true"
  
}
provider "google-beta" {
  project = var.project_id
  region = "northamerica-northeast1"
}
resource "google_cloudbuild_trigger" "test" {
     provider = google-beta
     project = "divine-energy-253221"
     name = "Terraform-plan-${var.env}"
     description = "A trigger to push to any branch"

    github {
      name = "terraform-gcp"
      owner = "ashish210290"
      push {
        branch = "^main$"
      }
    }
    filename = "cloud-build/tf-plan-project.yaml"
    substitutions = {
      _BACKEND_CONFIG_PREFIX: "terraform/${var.env}"
      _TF_COMMAND = "plan"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "../tfvars/pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    approval_config {
      approval_required = false
    }
    included_files = ["terraform/**"]
}


# Create Trigger for terraform apply, approval required ##


resource "google_cloudbuild_trigger" "trigger-apply" {
     provider = google-beta
     project = "divine-energy-253221"
     name = "Terraform-apply-${var.env}"
     description = "A trigger to apply terraform on git push to main"

    github {
      name = "terraform-gcp"
      owner = "ashish210290"
      push {
        branch = "^${var.data_platform_ops_br}$"
      }
    }
    filename = "cloud-build/tf-apply-project.yaml"
    substitutions = {
      _BACKEND_CONFIG_PREFIX: "terraform/${var.env}"
      _TF_COMMAND = "apply"
      _TF_OPTION = "-auto-approve"
      _VAR_FILES = "../tfvars/pr.tfvars"
      _TF_EXTRA_OPTION = "-lock=false"
    }
    approval_config {
      approval_required = true
    }
    included_files = ["terraform/**"]
}

resource "google_monitoring_alert_policy" "test_alert_policy_name" {
  
  project = "divine-energy-253221"
  display_name = "My Alert Policy"
  combiner     = "OR"

  conditions {
    display_name = "test condition - metrics missing"
    condition_absent {
      filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration = "300s"

      trigger {
        count = 1
      }
      
      aggregations {
        alignment_period = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  enabled = true
  notification_channels = ["projects/divine-energy-253221/notificationChannels/16399540197443471345"]
}

resource "google_monitoring_alert_policy" "Alert-Policy-1" {
    project = "divine-energy-253221"
    display_name = "My Alert POlicy 1"
    combiner = "OR"
    conditions {
      display_name = "Test Conditions 1"
      condition_threshold {
      filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration = "60s"
      comparison = "COMPARISON_GT"
      aggregations {
        alignment_period = "60s"
        per_series_aligner = "ALIGN_NONE"
      }
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      }     
    }
    user_labels = {
      foo = "bar"
    }
}

 resource "google_monitoring_alert_policy" "nifi_jvm_metrics_status" {
  project               = "divine-energy-253221"
  display_name          = "[${var.env}] NiFi JVM is down for 5 mins"
  documentation {
    content = "Either Prod NiFi instance is down or its bindplane agent is not running"
    mime_type = "text/markdown"
  }
  severity = "CRITICAL"
  notification_channels = ["projects/divine-energy-253221/notificationChannels/16399540197443471345"]
  combiner              = "OR"
  enabled               = var.enable_nifi_alert

  conditions {
    display_name = "NiFi is down - prometheus/nifi_jvm_uptime/gauge is missing"
    condition_absent {
      filter   = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_NONE"
      }
    }
  }
}

# Create three Regional Disks 

provider "google" {
  project = var.project_id
  region =  var.region
}

resource "google_compute_region_disk" "sftpgo-region-disk" {
  count = 3
  name = "sftpgo-region-disk-${count.index}"
  region = "northamerica-northeast1"
  replica_zones = ["northamerica-northeast1-a", "northamerica-northeast1-b"]
  size = 10
  type = "pd-balanced"

  labels = {
    environment = "non-prod"
  }
}


# Verify that disk is created correctly.

output "sftpgo-region-disk" {
  value = google_compute_region_disk.sftpgo-region-disk
}

# Create a compute instance to just to formart the regional disk 

resource "google_compute_instance" "disk-formatter" {
  count = 3
  name    = "format-disk-instance-${count.index}"
  machine_type = "n1-standard-1"
  zone = "northamerica-northeast1-a"
  scheduling {
    preemptible       = true
    automatic_restart = false
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    auto_delete = true
    initialize_params {
    image = "cos-cloud/cos-113-lts"
    size = 20
    type = "pd-balanced"
    }
    mode = "READ_WRITE"
  }

  attached_disk {
    source = google_compute_region_disk.sftpgo-region-disk[count.index].id
    device_name = "sftp-existing-disk"
  }
  network_interface {
   network = "default"
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config

      bootcmd:
      - mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
      - mkdir -p /mnt/disks/sftpgo
      - mount -o discard,defaults /dev/sdb /mnt/disks/sftpgo
      - chmod 777 /mnt/disks/sftpgo
      - spleep 60
      - echo "Tasks are completed. Shutting down."
      - sudo shutdown -h now
    EOF
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [ google_compute_region_disk.sftpgo-region-disk ]
  
}

# deattach regional disks from temporary disk-formatter instances

resource "google_compute_instance" "disk-formatter-deattach" {
  count = 3
  name    = "google_compute_instance.disk-formatter.format-disk-instance[${count.index}]"
  machine_type = "n1-standard-1"
  zone = "northamerica-northeast1-a"
  scheduling {
    preemptible       = true
    automatic_restart = false
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    auto_delete = true
    initialize_params {
    image = "cos-cloud/cos-113-lts"
    size = 20
    type = "pd-balanced"
    }
    mode = "READ_WRITE"
  }

  network_interface {
   network = "default"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [ google_compute_instance.disk-formatter ]
}


 ##Create an instance template

resource "google_compute_instance_template" "instance_template_0" {
  name           = "sftpgo-instance-template-0"
  machine_type   = "e2-micro"

  
  disk {
    auto_delete  = true
    boot         = true
    source_image = "projects/cos-cloud/global/images/family/cos-stable"  # Container-Optimized OS
    disk_type = "pd-standard"
    disk_size_gb = 20
  }

  disk {
    source      = "${google_compute_region_disk.sftpgo-region-disk.0.self_link}"
    device_name = "sftpgo-region-disk-0"
    mode        = "rw"
    auto_delete = false
    boot = false
  }
  network_interface {
    network = "default"
  }

  metadata = {

    user-data = <<-EOF
      #cloud-config
      
      bootcmd:
      - mkdir -p /mnt/disks/sftpgo
      - mount -o discard,defaults /dev/sdb /mnt/disks/sftpgo
      - chmod 777 /mnt/disks/sftpgo
    EOF
    gce-container-declaration = <<-EOF
      spec:
        containers:
          - name: sftpgo
            image: drakkan/sftpgo
            volumeMounts:
              - mountPath: /var/lib/sftpgo
                name: sftpgo-vol
        volumes:
          - name: sftpgo-vol
            hostPath:
              path: /mnt/disks/sftpgo
    EOF
  }

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["http-server"]
}

# # Create an instance template
# resource "google_compute_instance_template" "instance_template_1" {
#   name           = "sftpgo-instance-template-1"
#   machine_type   = "e2-micro"

  
#   disk {
#     auto_delete  = true
#     boot         = true
#     source_image = "projects/cos-cloud/global/images/family/cos-stable"  # Container-Optimized OS
#     disk_type = "pd-standard"
#     disk_size_gb = 20
#   }

#   disk {
#     source      = "${google_compute_region_disk.sftpgo-region-disk.1.self_link}"
#     device_name = "sftpgo-region-disk-1"
#     mode        = "rw"
#     auto_delete = false
#     boot = false
#   }
#   network_interface {
#     network = "default"
#   }

#   metadata = {

#     user-data = <<-EOF
#       #cloud-config
#       bootcmd:
#       - mkdir -p /mnt/disks/sftpgo
#       - mount -o discard,defaults /dev/sdb /mnt/disks/sftpgo
#       - chmod 777 /mnt/disks/sftpgo
#     EOF
#     gce-container-declaration = <<-EOF
#       spec:
#         containers:
#           - name: sftpgo
#             image: drakkan/sftpgo
#             volumeMounts:
#               - mountPath: /var/lib/sftpgo
#                 name: sftpgo-vol
#         volumes:
#           - name: sftpgo-vol
#             hostPath:
#               path: /mnt/disks/sftpgo
#     EOF
#   }

#   service_account {
#     email  = "default"
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   tags = ["http-server"]
# }

# # Create an instance template
# resource "google_compute_instance_template" "instance_template_2" {
#   name           = "sftpgo-instance-template-2"
#   machine_type   = "e2-micro"

  
#   disk {
#     auto_delete  = true
#     boot         = true
#     source_image = "projects/cos-cloud/global/images/family/cos-stable"  # Container-Optimized OS
#     disk_type = "pd-standard"
#     disk_size_gb = 20
#   }

#   disk {
#     source      = "${google_compute_region_disk.sftpgo-region-disk.2.self_link}"
#     device_name = "regional-disk-2"
#     mode        = "rw"
#     auto_delete = false
#     boot = false
#   }
#   network_interface {
#     network = "default"
#   }

#   metadata = {

#     user-data = <<-EOF
#       #cloud-config
#       bootcmd:
#       - mkdir -p /mnt/disks/sftpgo
#       - mount -o discard,defaults /dev/sdb /mnt/disks/sftpgo
#       - chmod 777 /mnt/disks/sftpgo
#     EOF
#     gce-container-declaration = <<-EOF
#       spec:
#         containers:
#           - name: sftpgo
#             image: drakkan/sftpgo
#             volumeMounts:
#               - mountPath: /var/lib/sftpgo
#                 name: sftpgo-vol
#         volumes:
#           - name: sftpgo-vol
#             hostPath:
#               path: /mnt/disks/sftpgo
#     EOF
#   }

#   service_account {
#     email  = "default"
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   tags = ["http-server"]
# }


# Create a managed instance group for sftpgo

resource "google_compute_instance_group_manager" "instance-group-manager" {
  name = "sftp-instance-group-manager"
  base_instance_name = "sftp-instance"
  zone = "northamerica-northeast1-a"
  target_size = 1

  version {
    instance_template = google_compute_instance_template.instance_template_0.self_link
  }
  # version {
  #   instance_template = google_compute_instance_template.instance_template_1.self_link
  # }
  # version {
  #   instance_template = google_compute_instance_template.instance_template_2.self_link
  # }


  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.default.self_link
    initial_delay_sec = 300
  }
}
resource "google_compute_health_check" "default" {
  name               = "health-check"
  check_interval_sec = 10
  timeout_sec        = 5
  healthy_threshold  = 3
  unhealthy_threshold = 3

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/"
  }
}