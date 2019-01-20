#!/bin/bash
oc delete -n istio-operator installation istio-installation
oc process -f istio_product_operator_template.yaml | oc delete -f -