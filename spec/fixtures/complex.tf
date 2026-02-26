resource "google_compute_instance" "batch" {
  count = var.enabled ? 1 : 0

  metadata = {
    startup-script = <<EOF_INNER
#!/bin/bash
echo hello
EOF_INNER
  }

  labels = { for k, v in var.labels : k => v if v != null }

  dynamic "network_interface" {
    for_each = var.networks
    content {
      subnetwork = network_interface.value.subnetwork
    }
  }
}
