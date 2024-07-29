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

# Create Trigger to cloud run deployment ##


resource "google_cloudbuild_trigger" "cloud-run-deployment" {
     provider = google-beta
     project = "divine-energy-253221"
     name = "Cloud-Run-Deployment-${var.env}"
     description = "A trigger to deploy token app on git push to main"

    github {
      name = "sbtoken-app"
      owner = "ashish210290"
      push {
        branch = "^${var.data_platform_ops_br}$"
      }
    }
    filename = "cloudbuild.yaml"
    substitutions = {
      _BACKEND_CONFIG_PREFIX: "terraform/tokenapp-${var.env}"
      _VAR_FILE: "tfvars/${var.env}.tfvars"
    }
    # approval_config {
    #   approval_required = true
    # }
    included_files = ["terraform/**"]
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

# resource "google_monitoring_alert_policy" "test_alert_policy_name" {
  
#   project = "divine-energy-253221"
#   display_name = "My Alert Policy"
#   combiner     = "OR"

#   conditions {
#     display_name = "test condition - metrics missing"
#     condition_absent {
#       filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
#       duration = "300s"

#       trigger {
#         count = 1
#       }
      
#       aggregations {
#         alignment_period = "300s"
#         per_series_aligner = "ALIGN_MEAN"
#       }
#     }
#   }
#   enabled = true
#   notification_channels = ["projects/divine-energy-253221/notificationChannels/16399540197443471345"]
# }

# resource "google_monitoring_alert_policy" "Alert-Policy-1" {
#     project = "divine-energy-253221"
#     display_name = "My Alert POlicy 1"
#     combiner = "OR"
#     conditions {
#       display_name = "Test Conditions 1"
#       condition_threshold {
#       filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
#       duration = "60s"
#       comparison = "COMPARISON_GT"
#       aggregations {
#         alignment_period = "60s"
#         per_series_aligner = "ALIGN_NONE"
#       }
#       evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
#       }     
#     }
#     user_labels = {
#       foo = "bar"
#     }
# }

#  resource "google_monitoring_alert_policy" "nifi_jvm_metrics_status" {
#   project               = "divine-energy-253221"
#   display_name          = "[${var.env}] NiFi JVM is down for 5 mins"
#   documentation {
#     content = "Either Prod NiFi instance is down or its bindplane agent is not running"
#     mime_type = "text/markdown"
#   }
#   severity = "CRITICAL"
#   notification_channels = ["projects/divine-energy-253221/notificationChannels/16399540197443471345"]
#   combiner              = "OR"
#   enabled               = var.enable_nifi_alert

#   conditions {
#     display_name = "NiFi is down - prometheus/nifi_jvm_uptime/gauge is missing"
#     condition_absent {
#       filter   = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
#       duration = "300s"
#       trigger {
#         count = 1
#       }
#       aggregations {
#         alignment_period     = "300s"
#         per_series_aligner   = "ALIGN_MEAN"
#         cross_series_reducer = "REDUCE_NONE"
#       }
#     }
#   }
# }

# # Create one Regional Disks 

## Create a bucket

resource "google_storage_bucket" "sftpgo-gcs" {
  name = "sftpgo-gcs"
  location = "northamerica-northeast1"
}

# Create a folder in sftpgo bucket
resource "google_storage_bucket_object" "sftpgo-container-volumes" {
  name = "sftpgo-container-volumes/"
  content = " "
  bucket = google_storage_bucket.sftpgo-gcs.name
}

#Create three sub-folders for data, config and user-data

resource "google_storage_bucket_object" "sftpgo-gcs-bucket-sub-folders" {
  for_each = toset(["db","config","user-data"])
  name = "sftpgo-container-volumes/${each.key}/"
  content = " "
  bucket = google_storage_bucket.sftpgo-gcs.name
}

resource "google_storage_bucket_object" "config-sftpgo-json" {
  name = "sftpgo-container-volumes/config/sftpgo.json"
  bucket = google_storage_bucket.sftpgo-gcs.name
  content = <<-EOT
  {
  "common": {
    "idle_timeout": 15,
    "upload_mode": 0,
    "actions": {
      "execute_on": [],
      "execute_sync": [],
      "hook": ""
    },
    "setstat_mode": 0,
    "rename_mode": 0,
    "resume_max_size": 0,
    "temp_path": "",
    "proxy_protocol": 1,
    "proxy_allowed": [],
    "proxy_skipped": [],
    "startup_hook": "",
    "post_connect_hook": "",
    "post_disconnect_hook": "",
    "data_retention_hook": "",
    "max_total_connections": 0,
    "max_per_host_connections": 20,
    "allowlist_status": 0,
    "allow_self_connections": 0,
    "umask": "",
    "server_version": "",
    "metadata": {
      "read": 0
    },
    "defender": {
      "enabled": false,
      "driver": "memory",
      "ban_time": 30,
      "ban_time_increment": 50,
      "threshold": 15,
      "score_invalid": 2,
      "score_valid": 1,
      "score_limit_exceeded": 3,
      "score_no_auth": 0,
      "observation_time": 30,
      "entries_soft_limit": 100,
      "entries_hard_limit": 150,
      "login_delay": {
        "success": 0,
        "password_failed": 1000
      }
    },
    "rate_limiters": [
      {
        "average": 0,
        "period": 1000,
        "burst": 1,
        "type": 2,
        "protocols": [
          "SSH",
          "FTP",
          "DAV",
          "HTTP"
        ],
        "generate_defender_events": false,
        "entries_soft_limit": 100,
        "entries_hard_limit": 150
      }
    ]
  },
  "acme": {
    "domains": [],
    "email": "",
    "key_type": "4096",
    "certs_path": "certs",
    "ca_endpoint": "https://acme-v02.api.letsencrypt.org/directory",
    "renew_days": 30,
    "http01_challenge": {
      "port": 80,
      "proxy_header": "",
      "webroot": ""
    },
    "tls_alpn01_challenge": {
      "port": 0
    }
  },
  "sftpd": {
    "bindings": [
      {
        "port": 2022,
        "address": "",
        "apply_proxy_config": true
      }
    ],
    "max_auth_tries": 0,
    "host_keys": [],
    "host_certificates": [],
    "host_key_algorithms": [],
    "kex_algorithms": [],
    "min_dh_group_exchange_key_size": 2048,
    "ciphers": [],
    "macs": [],
    "public_key_algorithms": [],
    "trusted_user_ca_keys": [],
    "revoked_user_certs_file": "",
    "login_banner_file": "",
    "enabled_ssh_commands": [
      "md5sum",
      "sha1sum",
      "sha256sum",
      "cd",
      "pwd",
      "scp"
    ],
    "keyboard_interactive_authentication": true,
    "keyboard_interactive_auth_hook": "",
    "password_authentication": true,
    "folder_prefix": ""
  },
  "ftpd": {
    "bindings": [
      {
        "port": 0,
        "address": "",
        "apply_proxy_config": true,
        "tls_mode": 0,
        "tls_session_reuse": 0,
        "certificate_file": "",
        "certificate_key_file": "",
        "min_tls_version": 12,
        "force_passive_ip": "",
        "passive_ip_overrides": [],
        "passive_host": "",
        "client_auth_type": 0,
        "tls_cipher_suites": [],
        "passive_connections_security": 0,
        "active_connections_security": 0,
        "ignore_ascii_transfer_type": 0,
        "debug": false
      }
    ],
    "banner_file": "",
    "active_transfers_port_non_20": true,
    "passive_port_range": {
      "start": 50000,
      "end": 50100
    },
    "disable_active_mode": false,
    "enable_site": false,
    "hash_support": 0,
    "combine_support": 0,
    "certificate_file": "",
    "certificate_key_file": "",
    "ca_certificates": [],
    "ca_revocation_lists": []
  },
  "webdavd": {
    "bindings": [
      {
        "port": 0,
        "address": "",
        "enable_https": false,
        "certificate_file": "",
        "certificate_key_file": "",
        "min_tls_version": 12,
        "client_auth_type": 0,
        "tls_cipher_suites": [],
        "tls_protocols": [],
        "prefix": "",
        "proxy_allowed": [],
        "client_ip_proxy_header": "",
        "client_ip_header_depth": 0,
        "disable_www_auth_header": false
      }
    ],
    "certificate_file": "",
    "certificate_key_file": "",
    "ca_certificates": [],
    "ca_revocation_lists": [],
    "cors": {
      "enabled": false,
      "allowed_origins": [],
      "allowed_methods": [],
      "allowed_headers": [],
      "exposed_headers": [],
      "allow_credentials": false,
      "max_age": 0,
      "options_passthrough": false,
      "options_success_status": 0,
      "allow_private_network": false
    },
    "cache": {
      "users": {
        "expiration_time": 1,
        "max_size": 1
      },
      "mime_types": {
        "enabled": true,
        "max_size": 1000,
        "custom_mappings": []
      }
    }
  },
  "data_provider": {
    "driver": "sqlite",
    "name": "sftpgo.db",
    "host": "",
    "port": 0,
    "username": "",
    "password": "",
    "sslmode": 0,
    "disable_sni": false,
    "target_session_attrs": "",
    "root_cert": "",
    "client_cert": "",
    "client_key": "",
    "connection_string": "",
    "sql_tables_prefix": "",
    "track_quota": 2,
    "delayed_quota_update": 0,
    "pool_size": 0,
    "users_base_dir": "/srv/sftpgo/data",
    "actions": {
      "execute_on": [],
      "execute_for": [],
      "hook": ""
    },
    "external_auth_hook": "",
    "external_auth_scope": 0,
    "credentials_path": "",
    "pre_login_hook": "",
    "post_login_hook": "",
    "post_login_scope": 0,
    "check_password_hook": "",
    "check_password_scope": 0,
    "password_hashing": {
      "bcrypt_options": {
        "cost": 10
      },
      "argon2_options": {
        "memory": 65536,
        "iterations": 1,
        "parallelism": 2
      },
      "algo": "bcrypt"
    },
    "password_validation": {
      "admins": {
        "min_entropy": 0
      },
      "users": {
        "min_entropy": 0
      }
    },
    "password_caching": true,
    "update_mode": 0,
    "create_default_admin": false,
    "naming_rules": 5,
    "is_shared": 1,
    "node": {
      "host": "",
      "port": 0,
      "proto": "http"
    },
    "backups_path": "/srv/sftpgo/backups"
  },
  "httpd": {
    "bindings": [
      {
        "port": 8080,
        "address": "",
        "enable_web_admin": true,
        "enable_web_client": true,
        "enable_rest_api": true,
        "enabled_login_methods": 0,
        "enable_https": false,
        "certificate_file": "",
        "certificate_key_file": "",
        "min_tls_version": 12,
        "client_auth_type": 0,
        "tls_cipher_suites": [],
        "tls_protocols": [],
        "proxy_allowed": [],
        "client_ip_proxy_header": "",
        "client_ip_header_depth": 0,
        "hide_login_url": 0,
        "render_openapi": true,
        "oidc": {
          "client_id": "",
          "client_secret": "",
          "client_secret_file": "",
          "config_url": "",
          "redirect_base_url": "",
          "scopes": [
            "openid",
            "profile",
            "email"
          ],
          "username_field": "",
          "role_field": "",
          "implicit_roles": false,
          "custom_fields": [],
          "insecure_skip_signature_check": false,
          "debug": false
        },
        "security": {
          "enabled": false,
          "allowed_hosts": [],
          "allowed_hosts_are_regex": false,
          "hosts_proxy_headers": [],
          "https_redirect": false,
          "https_host": "",
          "https_proxy_headers": [],
          "sts_seconds": 0,
          "sts_include_subdomains": false,
          "sts_preload": false,
          "content_type_nosniff": false,
          "content_security_policy": "",
          "permissions_policy": "",
          "cross_origin_opener_policy": ""
        },
        "branding": {
          "web_admin": {
            "name": "",
            "short_name": "",
            "favicon_path": "",
            "logo_path": "",
            "disclaimer_name": "",
            "disclaimer_path": "",
            "default_css": [],
            "extra_css": []
          },
          "web_client": {
            "name": "",
            "short_name": "",
            "favicon_path": "",
            "logo_path": "",
            "disclaimer_name": "",
            "disclaimer_path": "",
            "default_css": [],
            "extra_css": []
          }
        }
      }
    ],
    "templates_path": "templates",
    "static_files_path": "static",
    "openapi_path": "openapi",
    "web_root": "",
    "certificate_file": "",
    "certificate_key_file": "",
    "ca_certificates": [],
    "ca_revocation_lists": [],
    "signing_passphrase": "",
    "signing_passphrase_file": "",
    "token_validation": 1,
    "max_upload_file_size": 0,
    "cors": {
      "enabled": false,
      "allowed_origins": [],
      "allowed_methods": [],
      "allowed_headers": [],
      "exposed_headers": [],
      "allow_credentials": false,
      "max_age": 0,
      "options_passthrough": false,
      "options_success_status": 0,
      "allow_private_network": false
    },
    "setup": {
      "installation_code": "",
      "installation_code_hint": "Installation code"
    },
    "hide_support_link": false
  },
  "telemetry": {
    "bind_port": 0,
    "bind_address": "127.0.0.1",
    "enable_profiler": false,
    "auth_user_file": "",
    "certificate_file": "",
    "certificate_key_file": "",
    "min_tls_version": 12,
    "tls_cipher_suites": [],
    "tls_protocols": []
  },
  "http": {
    "timeout": 20,
    "retry_wait_min": 2,
    "retry_wait_max": 30,
    "retry_max": 3,
    "ca_certificates": [],
    "certificates": [],
    "skip_tls_verify": false,
    "headers": []
  },
  "command": {
    "timeout": 30,
    "env": [],
    "commands": []
  },
  "kms": {
    "secrets": {
      "url": "",
      "master_key": "",
      "master_key_path": ""
    }
  },
  "mfa": {
    "totp": [
      {
        "name": "Default",
        "issuer": "SFTPGo",
        "algo": "sha1"
      }
    ]
  },
  "smtp": {
    "host": "",
    "port": 587,
    "from": "",
    "user": "",
    "password": "",
    "auth_type": 0,
    "encryption": 0,
    "domain": "",
    "templates_path": "templates",
    "debug": 0,
    "oauth2": {
      "provider": 0,
      "tenant": "",
      "client_id": "",
      "client_secret": "",
      "refresh_token": ""
    }
  },
  "plugins": []
}
EOT
}





#--------------------------secret_manager_sa----------------#
# Create Service Account to manage secrets |
#------------------------------------------#

resource "google_service_account" "secrets-manager-sa" {
  account_id = "secrets-manager-sa"
  display_name = "Dataplatform Ops Secret Manager Service Account"  
}

#--------------------------------------------------------#
# Create Service Account to deploy TokenApp on cloud run |
#--------------------------------------------------------#
resource "google_service_account" "cloud-run-sa" {
  account_id = "cloud-run-sa"
  display_name = "Cloud Run Service Account to manage Token App"
}

#--------------------------------------------------------------------------------#
# Define roles to be assigned to secret Manger SA and Cloud Run SA for Token App |
#--------------------------------------------------------------------------------#

locals {
  secret_manager_roles = [
    "roles/secretmanager.viewer"
  ]

  cloud_run_roles = [
    "roles/run.developer",
    "roles/run.invoker",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.secretAccessor"
  ]
}

#------------------------------------------#
# Assign roles to Secret Manager SA account|
#------------------------------------------#

resource "google_project_iam_member" "secrets-manager-sa" {
  for_each = toset(local.secret_manager_roles)

  project = var.project_id
  role = each.value
  member = "serviceAccount:${google_service_account.secrets-manager-sa.email}"
}

#------------------------------------------#
# Assign roles to Cloud Run SA account|
#------------------------------------------#

resource "google_project_iam_member" "cloud-run-sa" {
  for_each = toset(local.cloud_run_roles)

  project = var.project_id
  role = each.value
  member = "serviceAccount:${google_service_account.cloud-run-sa.email}"
}


## Provide and region details
provider "google" {
  project = var.project_id
  region =  var.region
}

#-------------------------------------#
# Create an Instance Template for MIG |
#-------------------------------------#

resource "google_compute_instance_template" "instance_template_0" {
  count = 1
  name_prefix           = "sftpgo-instance-template-"
  machine_type          = "e2-micro"
  

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
    access_config {
      
    }
    
  }

  metadata = {
    enable-oslogin = "TRUE"
    user-data = <<-EOF
#cloud-config

bootcmd:
- |
  #!/bin/bash
  if grep -q '^Port' /etc/ssh/sshd_config; then
  sed -i 's/^Port.*/Port 2222/' /etc/ssh/sshd_config
    else
  echo 'Port 2222' >> /etc/ssh/sshd_config
  fi
- systemctl daemon-reload
- systemctl restart sshd
- echo 'root:Hello@1234' | chpasswd

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
    ExecStart=/usr/bin/docker run --rm --name=gcpfuse-mounter --privileged --volume /dev/fuse:/dev/fuse --volume /mnt/disks/sftpgo:/mnt/sftpgo:shared  northamerica-northeast1-docker.pkg.dev/divine-energy-253221/gcp-repo/gcs-bucket-mount:latest
    ExecStop=/usr/bin/docker stop sftpgo-gcpfuse
    ExecStopPost=/usr/bin/docker rm sftpgo-gcpfuse

- path: /etc/systemd/system/sftpgo.service
  permissions: 0644
  owner: root
  content: |
    [Unit]
    Description=SFTPGo container
    After=sftpgo-gcpfuse.service
    Requires=sftpgo-gcpfuse.service

    [Service]
    ExecStart=/usr/bin/docker run --rm --name sftpgo --privileged -p 22:2022 -p 8080:8080 --volume /mnt/disks/sftpgo/db:/var/lib/sftpgo:shared --volume  /mnt/disks/sftpgo/config:/etc/sftpgo:shared --volume  /mnt/disks/sftpgo/user-data:/srv/sftpgo/data:shared drakkan/sftpgo:latest
    ExecStop=/usr/bin/docker stop sftpgo.service
    ExecStopPost=/usr/bin/docker rm sftpgo.service
    Restart=always

    [Install]
    WantedBy=default.target

runcmd:
- |
  #!/bin/bash
  if grep -q '^Port' /etc/ssh/sshd_config; then
  sed -i 's/^Port.*/Port 2222/' /etc/ssh/sshd_config
    else
  echo 'Port 2222' >> /etc/ssh/sshd_config
  fi
- systemctl daemon-reload
- echo 'root:Hello@1234' | chpasswd
- systemctl restart sshd
- systemctl enable sftpgo-gcpfuse.service
- systemctl start sftpgo-gcpfuse.service
- sleep 30
- systemctl enable sftpgo.service
- systemctl restart sftpgo.service

EOF 
  }

  service_account {
    email  = "sftpgo-sa@divine-energy-253221.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  tags = ["sftpgo-server"]


  lifecycle {
    create_before_destroy = true
  }

  depends_on = [ google_storage_bucket_object.config-sftpgo-json ]
}

#--------------------------------------------#
# Create a Managed Instance Group for sftpgo |
#--------------------------------------------#

resource "google_compute_instance_group_manager" "instance-group-manager-0" {
  count = 1
  name = "sftp-instance-group-manager-0"
  base_instance_name = "sftp-instance"
  zone = "northamerica-northeast1-a"
  target_size = 3

  version {
    instance_template = "google_compute_instance_template.instance_template_0[count.index]"
    #instance_template = google_compute_instance_template.instance_template_0.self_link
  }
 
  named_port {
    name = "http-sftp"
    port = 8080
  }

  named_port {
    name = "ssh-sftpgo"
    port = 22
  }
  
  auto_healing_policies {
    health_check      = "google_compute_health_check.sftpgo-health-ssh-check[count.index]"
    initial_delay_sec = 300

  }
  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------#
# Health Check at port 22 and 2222 for MIG |
#-----------------------------------#

resource "google_compute_health_check" "sftpgo-health-ssh-check" {
  count = 1
  name               = "sftpgo-health-ssh-check"
  check_interval_sec = 50
  timeout_sec        = 10
  healthy_threshold  = 1
  unhealthy_threshold = 10

  tcp_health_check {
    port = "22"
  }
  
}

resource "time_sleep" "wait_300_seconds" {
  depends_on = [google_compute_instance_group_manager.instance-group-manager-0]

  create_duration = "299s"
}

#-----------------------------------------------------------------------------------------------------------------#
# Create External Passthrough Network Load-Balancer (NLB)                                                         | 
# Resources to create NLB - TCP health-check, backend-service, public IP and port (2022 and 8080) forwarding rules|
#-----------------------------------------------------------------------------------------------------------------#

  #-----------------------------------------#
  # i. Health Check on TCP port 8080        |
  #-----------------------------------------# 

resource "google_compute_region_health_check" "sftpgo-health-http-check" {
  name               = "sftpgo-health-http-check"
  check_interval_sec = 50
  timeout_sec        = 10
  healthy_threshold  = 3
  unhealthy_threshold = 10

  tcp_health_check {
    port = "8080"
  }
  depends_on = [time_sleep.wait_300_seconds]
}

  #----------------------------------------#
  # ii. Create Public Ip for Load-Balancer |
  #----------------------------------------#

# resource "google_compute_address" "sftpgo-nlb-address" {
#  provider      = google-beta
#  name          = "sftpgo-nlb-address"
#  ip_version    = "IPV4"
#  depends_on = [time_sleep.wait_300_seconds]
# }

  #----------------------------------------------#
  # iii. Create Backend serice for Load-Balancer |
  #----------------------------------------------#

resource "google_compute_region_backend_service" "nlb-backend-service-0" {
  name = "nlb-backend-service-0"
  region = "northamerica-northeast1"
  health_checks = [google_compute_region_health_check.sftpgo-health-http-check.id]
  load_balancing_scheme = "INTERNAL"
  protocol = "TCP"
  timeout_sec = 30
  connection_draining_timeout_sec = 300
  #locality_lb_policy = "MAGLEV"
  session_affinity = "CLIENT_IP_PROTO"
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
  # iv. Create Forwarding rules for SftpGo ports 22 and 8080 |
  #------------------------------------------------------------#


resource "google_compute_forwarding_rule" "tcp8080-22-forwarding-rule" {
  name = "tcp8080-22-forwarding-rule"
  backend_service = google_compute_region_backend_service.nlb-backend-service-0.id
  ip_address = "10.162.0.10"
  ports = [ "22", "8080" ]
  #target = google_compute_target_tcp_proxy.tcp_proxy.id
  ip_protocol = "TCP"
  ip_version = "IPV4"
  load_balancing_scheme = "INTERNAL"
  network_tier = "PREMIUM"
  subnetwork = "projects/divine-energy-253221/regions/northamerica-northeast1/subnetworks/default"
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
#- mkdir -p "/mnt/disks/sftpgo"