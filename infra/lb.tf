# ====================================================================
# Resource: Reserved Public IP
# This resource reserves a public IP for the load balancer if one 
# does not already exist. The public IP is associated with the load 
# balancer and should not be destroyed independently.
# ====================================================================

resource "oci_core_public_ip" "reserved_ip" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "${var.lb_display_name}-public-ip"

  # Public IP is managed by the load balancer and should not be modified independently
  provisioner "local-exec" {
    when       = destroy
    command    = "echo 'Cannot destroy public IP managed by load balancer'"
    on_failure = continue
  }
}

# ====================================================================
# Resource: Load Balancer
# This resource defines the load balancer for the Kubernetes API 
# server, including its shape, associated subnet, and reserved public IP.
# ====================================================================

resource "oci_load_balancer_load_balancer" "kubeapi_lb" {
  compartment_id             = var.compartment_ocid
  shape                      = var.public_lb_shape
  subnet_ids                 = [oci_core_subnet.k3s_subnet.id]
  network_security_group_ids = [oci_core_network_security_group.public_lb_nsg.id]
  is_private                 = false
  display_name               = "kubeapi-lb"

  reserved_ips {
    id = local.reserved_ip_id
  }

  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
}

# ====================================================================
# Resource: Backend Set for KubeAPI
# This resource defines the backend set for the KubeAPI server, 
# using a round-robin load balancing policy and a TCP health check.
# ====================================================================

resource "oci_load_balancer_backend_set" "kubeapi_backend_set" {
  load_balancer_id = oci_load_balancer_load_balancer.kubeapi_lb.id
  name             = "kubeapi-backend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "TCP"
    port     = var.kube_api_port
  }
}

# ====================================================================
# Resource: KubeAPI Listener
# This resource defines the listener for the KubeAPI server, 
# associating it with the backend set and configuring it to listen 
# on the specified port using the TCP protocol.
# ====================================================================

resource "oci_load_balancer_listener" "kubeapi_listener" {
  load_balancer_id         = oci_load_balancer_load_balancer.kubeapi_lb.id
  name                     = "kubeapi-listener"
  protocol                 = "TCP"
  port                     = var.kube_api_port
  default_backend_set_name = oci_load_balancer_backend_set.kubeapi_backend_set.name
  depends_on               = [oci_load_balancer_backend_set.kubeapi_backend_set]
}

# ====================================================================
# Resource: Backends for KubeAPI (Control Plane Nodes)
# This resource defines the backends for the KubeAPI server, associating 
# each control plane node with the backend set and configuring it to 
# communicate on the specified port.
# ====================================================================

resource "oci_load_balancer_backend" "kubeapi_backend" {
  count            = length(oci_core_instance.k3s_control_plane.*.private_ip)
  backendset_name  = oci_load_balancer_backend_set.kubeapi_backend_set.name
  ip_address       = element(oci_core_instance.k3s_control_plane.*.private_ip, count.index)
  load_balancer_id = oci_load_balancer_load_balancer.kubeapi_lb.id
  port             = var.kube_api_port
}
