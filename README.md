# generic-repo-template <!-- Change this to the title of the repository -->

> Repo description <!-- This should match the GitHub description -->

<!-- More description as needed -->

## Install

This project uses [package1]() and [library1]().

```sh
echo "place any install instructions here"
```

## Usage

```python
// Fill out with actual use case
example = print('Add code usage examples here')
```

<!-- Add any exported methods here. You can also create an API section. -->

## Contribute

Add contribution isnstructions, checklists etc. here
<!-- BEGIN_TF_DOCS -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_google"></a> [google](#requirement\_google) (~> 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_google"></a> [google](#provider\_google) (~> 4.0.0)

## Modules

The following Modules are called:

### <a name="module_jenkins"></a> [jenkins](#module\_jenkins)

Source: ./day-1

Version:

### <a name="module_load_balancer"></a> [load\_balancer](#module\_load\_balancer)

Source: ./day-2/load_balancer

Version:

### <a name="module_web_application"></a> [web\_application](#module\_web\_application)

Source: ./day-2/webserver

Version:

## Resources

The following resources are used by this module:

- [google_compute_firewall.allow_external_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_firewall.allow_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_firewall.allow_internal_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_firewall.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) (resource)
- [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) (resource)
- [google_compute_subnetwork.subnet_1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) (resource)
- [google_compute_subnetwork.subnet_2](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) (resource)

## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_project_id"></a> [project\_id](#input\_project\_id)

Description: The ID of the GCP project where resources will be deployed

Type: `string`

Default: `"<YOUR PROJECT HERE>"`

### <a name="input_region"></a> [region](#input\_region)

Description: The default GCP region to deploy resources to

Type: `string`

Default: `"europe-west2"`

## Outputs

The following outputs are exported:

### <a name="output_load_balancer_ip"></a> [load\_balancer\_ip](#output\_load\_balancer\_ip)

Description: n/a
<!-- END_TF_DOCS -->