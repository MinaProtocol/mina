# Terraform Deployments

This directory is a parent folder that holds code for instances of Terraform deployments. 

Instances in this folder are intended to be unique, atomic, and make use of predefined modules located in `./modules` directory.

> Duplicate deployments are _encouraged_

Even for deployments that use the same modules and are otherwise identical, it is still recommended that they live in unique deployment folders, so that their Terraform state configuration can remain unique, allowing future updates to be done using Terraform (rather than a manual edit).
