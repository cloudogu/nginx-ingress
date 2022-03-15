# Developers Guide

This documentation contains all information required for developing the Nginx-Ingress Dogu.

## Prerequisites

1. A running K8s-EcoSystem is required to develop the Nginx-Ingress Dogu. For more information about the
setup of the K8s-EcoSystem see …(TODO add link to K8s-EcoSystem setup)

1. An SSL certificate should be available in the K8s-EcoSystem. This should be accessible as a secret named
`ecosystem/ecosystem-certificate` in the K8s-EcoSystem.

## Overview of Available Make Targets

This project provides a make target named `help` to print all available targets and their description.

## Building and Deploying the Dogu

The Makefile contains a target `build` which does the following:

1. Builds the Dogu image.
1. Imports the image into all K8s-EcoSystem Nodes.
1. Applies all K8s resources from the `k8s` folder including a Deployment and Service for the Dogu.

The K8s-EcoSystem should now automatically start a pod for the dogu. 