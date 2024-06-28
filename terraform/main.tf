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
# resource "google_cloudbuild_trigger" "test" {
#      provider = google-beta
#      project = "divine-energy-253221"
#      name = "Terraform-plan-${var.env}"
#      description = "A trigger to push to any branch"

#     github {
#       name = "terraform-gcp"
#       owner = "ashish210290"
#       push {
#         branch = "^main$"
#       }
#     }
#     filename = "cloud-build/tf-plan-project.yaml"
#     substitutions = {
#       _BACKEND_CONFIG_PREFIX: "terraform/${var.env}"
#       _TF_COMMAND = "plan"
#       _TF_OPTION = "-auto-approve"
#       _VAR_FILES = "../tfvars/pr.tfvars"
#       _TF_EXTRA_OPTION = "-lock=false"
#     }
#     approval_config {
#       approval_required = false
#     }
#     included_files = ["terraform/**"]
# }


# # Create Trigger for terraform apply, approval required ##


# resource "google_cloudbuild_trigger" "trigger-apply" {
#      provider = google-beta
#      project = "divine-energy-253221"
#      name = "Terraform-apply-${var.env}"
#      description = "A trigger to apply terraform on git push to main"

#     github {
#       name = "terraform-gcp"
#       owner = "ashish210290"
#       push {
#         branch = "^${var.data_platform_ops_br}$"
#       }
#     }
#     filename = "cloud-build/tf-apply-project.yaml"
#     substitutions = {
#       _BACKEND_CONFIG_PREFIX: "terraform/${var.env}"
#       _TF_COMMAND = "apply"
#       _TF_OPTION = "-auto-approve"
#       _VAR_FILES = "../tfvars/pr.tfvars"
#       _TF_EXTRA_OPTION = "-lock=false"
#     }
#     approval_config {
#       approval_required = true
#     }
#     included_files = ["terraform/**"]
# }

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

# # Create one Regional Disks 

provider "google" {
  project = var.project_id
  region =  var.region
}

#-------------------------------------#
# Create an Instance Template for MIG |
#-------------------------------------#

resource "google_compute_instance_template" "instance_template_0" {
  #count = 3
  name_prefix           = "sftpgo-instance-template-"
  machine_type   = "e2-micro"
  

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
    
  disk {
    auto_delete  = true
    boot         = true
    source_image = "projects/cos-cloud/global/images/family/cos-stable"  # Container-Optimized OS
    disk_type = "pd-standard"
    disk_size_gb = 20
  }

  network_interface {
    network = "default"
  }

  metadata = {
    gce-container-declaration = <<-EOF
      spec:
        containers:
          - name: sftpgo
            image: drakkan/sftpgo
            volumeMounts:
               - mountPath: /var/lib/sftpgo
                 name: sftpgo-db-vol
               - mountPath: /etc/sftpgo
                 name: sftpgo-config-vol
               - mountPath: /srv/sftpgo/data
                 name: sftpgo-user-data-vol 
        volumes:
          - name: sftpgo-db-vol
            hostPath:
              path: /mnt/disks/sftpgo/db
          - name: sftpgo-config-vol
            hostPath:
              path: /mnt/disks/sftpgo/config
          - name: sftpgo-user-data-vol
            hostPath: 
              path: /mnt/disks/sftpgo/user-data      
              
    EOF
    user-data = <<-EOF
      #cloud-config
      
      write_files:
      - path: /etc/systemd/system/sftpgo-gcpfuse.service
        permissions: 0644
        owner: root
        content: |
          [Unit]
          Description=Start a GcpFuse docker container
          Wants=gcr-online.target
          After=gcr-online.target

          [Install]
          WantedBy=default.target

          [Service]
          Environment="HOME=/home/gcpfuse"
          ExecStartPre=/usr/bin/docker-credential-gcr configure-docker --registries northamerica-northeast1-docker.pkg.dev
          ExecStart=/usr/bin/docker run --rm --name=gcpfuse-mounter --privileged --volume /dev/fuse:/dev/fuse --volume /mnt/disks/sftpgo:/mnt/sftpgo:shared northamerica-northeast1-docker.pkg.dev/divine-energy-253221/gcp-repo/gcs-bucket-mount:latest
          ExecStop=/usr/bin/docker stop sftpgo-gcpfuse
          ExecStopPost=/usr/bin/docker rm sftpgo-gcpfuse

      runcmd:
      - mkdir -p "/mnt/disks/sftpgo"
      - systemctl daemon-reload
      - systemctl start sftpgo-gcpfuse.service
      - systemctl enable sftpgo-gcpfuse.service
    EOF 
  }

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["http-server"]

  lifecycle {
    create_before_destroy = true
  }
}

#--------------------------------------------#
# Create a Managed Instance Group for sftpgo |
#--------------------------------------------#

resource "google_compute_instance_group_manager" "instance-group-manager-0" {
  name = "sftp-instance-group-manager-0"
  base_instance_name = "sftp-instance"
  zone = "northamerica-northeast1-a"
  target_size = 3

  version {
    instance_template = google_compute_instance_template.instance_template_0.self_link
  }
 
  named_port {
    name = "http-sftp"
    port = 8080
  }

  named_port {
    name = "ssh-sftpgo"
    port = 2022
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.sftpgo-health-http-check.self_link
    initial_delay_sec = 300
  }

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------#
# Health Check at port 2022 for MIG |
#-----------------------------------#

resource "google_compute_health_check" "sftpgo-health-http-check" {
  name               = "sftpgo-health-ssh-check"
  check_interval_sec = 50
  timeout_sec        = 10
  healthy_threshold  = 5
  unhealthy_threshold = 10

  tcp_health_check {
    port = "2022"
  }
}

#-----------------------------------------------------------------------------------------------------------------#
# Create External Passthrough Network Load-Balancer (NLB)                                                         | 
# Resources to create NLB - TCP health-check, backend-service, public IP and port (2022 and 8080) forwarding rules|
#-----------------------------------------------------------------------------------------------------------------#

  #-----------------------------------------#
  # i. Health Check on TCP port 8080        |
  #-----------------------------------------# 

resource "google_compute_region_health_check" "sftpgo-health-ssh-check" {
  name               = "sftpgo-health-ssh-check"
  check_interval_sec = 50
  timeout_sec        = 10
  healthy_threshold  = 5
  unhealthy_threshold = 10

  tcp_health_check {
    port = "2022"
  }
}

  #----------------------------------------#
  # ii. Create Public Ip for Load-Balancer |
  #----------------------------------------#

resource "google_compute_global_address" "sftpgo-nlb-address" {
 provider      = google-beta
 name          = "sftpgo-nlb-address"
 ip_version    = "IPV4"
}

  #----------------------------------------------#
  # iii. Create Backend serice for Load-Balancer |
  #----------------------------------------------#

resource "google_compute_region_backend_service" "nlb-backend-service-0" {
  name = "nlb-backend-service-0"
  health_checks = [google_compute_region_health_check.sftpgo-health-ssh-check.id]
  load_balancing_scheme = "EXTERNAL"
  protocol = "TCP"
  timeout_sec = 30
  connection_draining_timeout_sec = 300
  #locality_lb_policy = "MAGLEV"
  session_affinity = "NONE"
  backend {
    group = google_compute_instance_group_manager.instance-group-manager-0.instance_group
    balancing_mode = "CONNECTION"
    #max_connections_per_instance = 100
    
  }
  log_config {
    enable = true
  }
}

  #------------------------------------------------------------#
  # iv. Create Forwarding rules for SftpGo ports 2022 and 8080 |
  #------------------------------------------------------------#

resource "google_compute_forwarding_rule" "tcp8080-2022-forwarding-rule" {
  name = "tcp8080-2022-forwarding-rule"
  backend_service = google_compute_region_backend_service.nlb-backend-service-0.id
  ip_address = google_compute_global_address.sftpgo-nlb-address.address
  ports = [ "8080", "2022" ]
  ip_protocol = "TCP"
  ip_version = "IPV4"
  load_balancing_scheme = "EXTERNAL"
  network_tier = "PREMIUM"
  region = var.region
}



































# resource "google_compute_region_disk" "sftpgo-region-disk" {
#   #count = 3
#   #name = "sftpgo-region-disk-${count.index}"
#   name = "sftpgo-region-disk"
#   region = "northamerica-northeast1"
#   replica_zones = ["northamerica-northeast1-a", "northamerica-northeast1-b", "northamerica-northeast1-c"]
#   size = 10
#   type = "pd-ssd"
# }

# # Create Persistent disk 
# resource "google_compute_disk" "sftpgo-pd-disk-2" {
#   name = "sftpgo-pd-disk-2"
#   type = "pd-standard"
#   size = 10
#   zone = "northamerica-northeast1-a"
# }




# # Create an instance template
# resource "google_compute_instance_template" "instance_template_0" {
#   #count = 3
#   name_prefix           = "sftpgo-instance-template-"
#   machine_type   = "e2-micro"

#   scheduling {
#     automatic_restart   = true
#     on_host_maintenance = "MIGRATE"
#   }
    
#   disk {
#     auto_delete  = true
#     boot         = true
#     source_image = "projects/cos-cloud/global/images/family/cos-stable"  # Container-Optimized OS
#     disk_type = "pd-standard"
#     disk_size_gb = 20
#   }

#   disk {
#     #source      = google_compute_region_disk.sftpgo-region-disk[count.index].id
#     source      = google_compute_region_disk.sftpgo-region-disk.id
#     #device_name = "sftpgo-region-disk-${count.index}"
#     device_name = "sftpgo-region-disk"
#     mode        = "READ_WRITE"
#     auto_delete = false
#     boot = false
#   }
#   network_interface {
#     network = "default"

#     access_config {
      
#     }
#   }

#   metadata = {
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
#     user-data = <<-EOF
#       #cloud-config
#       runcmd:
#       - |
#         #!/bin/bash
#         DISK_DEVICE="/dev/sdb"
#         MOUNT_POINT="/mnt/disks/sftpgo"
          
#         if ! blkid | grep -q "/dev/sdb";
#         then   
#           mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "/dev/sdb"
#         fi
          
#         mkdir -p "/mnt/disks/sftpgo"
          
#         mount -o discard,defaults  "/dev/sdb" "/mnt/disks/sftpgo"
        
#         chmod 777 /mnt/disks/sftpgo

#       bootcmd:
#       - mkdir -p "/mnt/disks/sftpgo" 
#       - mount -o discard,defaults  "/dev/sdb" "/mnt/disks/sftpgo"
#       - chmod 777 /mnt/disks/sftpgo

#     EOF 
#   }

#   service_account {
#     email  = "default"
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   tags = ["http-server"]

#   lifecycle {
#     create_before_destroy = true
#   }
# }



# # Create an instance template
# resource "google_compute_instance_template" "instance_template_0" {
#   #count = 3
#   name_prefix           = "sftpgo-instance-template-"
#   machine_type   = "e2-micro"

#   scheduling {
#     automatic_restart   = true
#     on_host_maintenance = "MIGRATE"
#   }
    
#   disk {
#     auto_delete  = true
#     boot         = true
#     source_image = "projects/cos-cloud/global/images/family/cos-stable"  # Container-Optimized OS
#     disk_type = "pd-standard"
#     disk_size_gb = 20
#   }

#   network_interface {
#     network = "default"

#     access_config {
      
#     }
#   }

#   metadata = {
#     gce-container-declaration = <<-EOF
#       spec:
#         containers:
#           - name: gcs-fuse
#             image:  northamerica-northeast1-docker.pkg.dev/divine-energy-253221/gcp-repo/gcs-bucket-mount
#             securityContext:
#               privileged: true
#             volumeMounts:
#             - name: dev-fuse
#               mountPath: /dev/fuse
#             - name: sftpgo-gcsfuse-share
#               mountPath: /mnt/sftpgo  
#               mountPropagation: "Bidirectional"

#           - name: sftpgo
#             image: drakkan/sftpgo
#             volumeMounts:
#               - mountPath: /var/lib/sftpgo
#                 name: sftpgo-vol
#         volumes:
#           - name: dev-fuse
#             mountPath: /dev/fuse
#           - name: sftpgo-gcsfuse-share
#             mountPath: /mnt/disks/sftpgo
#           - name: sftpgo-vol
#             hostPath:
#               path: /mnt/disks/sftpgo
#     EOF
#     user-data = <<-EOF
#       #cloud-config
#       runcmd:
#       - |
#         #!/bin/bash
          
#         mkdir -p "/mnt/disks/sftpgo"
        
#         chmod 777 /mnt/disks/sftpgo

#       bootcmd:
#       - mkdir -p "/mnt/disks/sftpgo"
#       - chmod 777 /mnt/disks/sftpgo
#     EOF 
#   }

#   service_account {
#     email  = "default"
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   tags = ["http-server"]

#   lifecycle {
#     create_before_destroy = true
#   }
# }





##############3
# # Verify that disk is created correctly.

# output "sftpgo-region-disk" {
#   value = google_compute_region_disk.sftpgo-region-disk
# }

# # Create a compute instance to just to formart the regional disk 

# resource "google_compute_instance" "disk-formatter" {
#   count = 3
#   name    = "format-disk-instance-${count.index}"
#   machine_type = "n1-standard-1"
#   zone = "northamerica-northeast1-a"
#   scheduling {
#     preemptible       = true
#     automatic_restart = false
#     on_host_maintenance = "TERMINATE"
#   }

#   boot_disk {
#     auto_delete = true
#     initialize_params {
#     image = "cos-cloud/cos-113-lts"
#     size = 20
#     type = "pd-balanced"
#     }
#     mode = "READ_WRITE"
#   }

#   attached_disk {
#     source = google_compute_region_disk.sftpgo-region-disk[count.index].id
#     device_name = "sftp-existing-disk"
#   }
#   network_interface {
#    network = "default"
#   }

#   metadata = {
#     user-data = <<-EOF
#       #cloud-config

#       bootcmd:
#       - mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
#       - spleep 60
#       - echo "Tasks are completed. Shutting down."
#       - sudo shutdown -h now
#     EOF
#   }

#   lifecycle {
#     ignore_changes = [ attached_disk ]
#   }

#   depends_on = [ google_compute_region_disk.sftpgo-region-disk ]
  
# }




# # Wait for the temporary instance to shut down before detaching the disk
# resource "null_resource" "wait_for_shutdown" {
#   depends_on = [ google_compute_instance.disk-formatter ]

#   provisioner "local-exec" {
#     command = "sleep 2m"
#   }

# }

# # Create a managed instance group for sftpgo

# resource "google_compute_instance_group_manager" "instance-group-manager-0" {
#   name = "sftp-instance-group-manager-0"
#   base_instance_name = "sftp-instance-rw"
#   zone = "northamerica-northeast1-a"
#   target_size = 1

#   version {
#     instance_template = google_compute_instance_template.instance_template_0.self_link
#   }
 
#   named_port {
#     name = "http-sftp"
#     port = 8080
#   }

#   named_port {
#     name = "ssh-sftpgo"
#     port = 2022
#   }

#   auto_healing_policies {
#     health_check      = google_compute_health_check.default.self_link
#     initial_delay_sec = 300
#   }
# }

# resource "google_compute_health_check" "default" {
#   name               = "health-check"
#   check_interval_sec = 60
#   timeout_sec        = 10
#   healthy_threshold  = 3
#   unhealthy_threshold = 3

#   tcp_health_check {
#     port = "8080"
#   }
# }