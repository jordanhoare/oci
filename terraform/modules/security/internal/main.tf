resource "oci_core_security_list" "internal_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "internal_security_list"

  ingress_security_rules {
    description = "Allow all traffic within the subnet"
    source      = var.subnet_cidr
    protocol    = "all"
  }

  ingress_security_rules {
    description = "Allow all traffic within the VCN"
    source      = var.vcn_cidr
    protocol    = "all"
  }

  egress_security_rules {
    description = "Allow all outbound traffic"
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    description = "Allow NodePort traffic on ports 30000-32767"
    source      = "0.0.0.0/0"
    protocol    = "6"

    tcp_options {
      min = 30000 
      max = 32767
    }
  }
}