#!/bin/bash

##Receta de instalación de Istio en Openshift

#Configuración de Memoria virtual para el despliegue de Elastichsearch
sysctl vm.max_map_count=262144

#Necesitamos acceder al cluster como Administrador
#Generamos un nuevo proyecto para el despliegue del operador de Istio
oc new-project istio-operator
#Realizamos el despliegue del operador de Istio utilizando un archivo yaml
#Utilizamos la version community de Istio #IP o nombre de dominio del servidor master
oc new-app -f istio_community_operator_template.yaml --param=OPENSHIFT_ISTIO_MASTER_PUBLIC_URL=192.168.99.100:8443

#Verificamos que el operador se haya instalado a traves de los logs que este genera
oc logs -n istio-operator $(oc -n istio-operator get pods -l name=istio-operator --output=jsonpath={.items..metadata.name})

#Realizamos el despliegue del plano de Control de Service Mesh (Istio, Kiali y Jaeger)
#Este archivo instala las herramientas utilizadas en el Service Mesh
#Utilizamos la version community de Istio
oc create -f cr_community.yaml -n istio-operator

#Verificamos que la instalación se lleve a cabo de forma correcta
oc get pods -n istio-system

#Para Istio es necesario configurar algunos permisos para las cuentas de servicio, que realizan el despliegue de las aplicaciones
#por lo general la mayoria de las aplicaciones utilizan la cuenta default
#Permisos requeridos (anyuid, privileged):
oc adm policy add-scc-to-user anyuid -z default -n myproject #Permisos anyuid para service account "default" en el proyecto "myproject"
oc adm policy add-scc-to-user privileged -z default -n myproject #Permisos privileged para service account "default" en el proyecto "myproject"

#Service Mesh se basa en la existencia de un sidecar proxy dentro del pod de la aplicación para proporcionar capacidades de malla de servicio a la aplicación. 
#A continuación habilitamos la inyeccion automatica del sidecar proxy

#######Realice los siguientes cambios en cada maestro#######
#Creación del archvio /etc/origin/master/master-config.patch (parche)
echo "YWRtaXNzaW9uQ29uZmlnOgogIHBsdWdpbkNvbmZpZzoKICAgIE11dGF0aW5nQWRtaXNzaW9uV2ViaG9vazoKICAgICAgY29uZmlndXJhdGlvbjoKICAgICAgICBhcGlWZXJzaW9uOiBhcGlzZXJ2ZXIuY29uZmlnLms4cy5pby92MWFscGhhMQogICAgICAgIGt1YmVDb25maWdGaWxlOiAvZGV2L251bGwKICAgICAgICBraW5kOiBXZWJob29rQWRtaXNzaW9uCiAgICBWYWxpZGF0aW5nQWRtaXNzaW9uV2ViaG9vazoKICAgICAgY29uZmlndXJhdGlvbjoKICAgICAgICBhcGlWZXJzaW9uOiBhcGlzZXJ2ZXIuY29uZmlnLms4cy5pby92MWFscGhhMQogICAgICAgIGt1YmVDb25maWdGaWxlOiAvZGV2L251bGwKICAgICAgICBraW5kOiBXZWJob29rQWRtaXNzaW9uCg==" | base64 -w0 -d > /etc/origin/master/master-config.patch

#Hacemos efectivo el parche (Ubicados en /etc/origin/master)
cp -p master-config.yaml master-config.yaml.prepatch
oc ex config patch master-config.yaml.prepatch -p "$(cat master-config.patch)" > master-config.yaml

#Reiniciamos el master
/usr/local/bin/master-restart api && /usr/local/bin/master-restart controllers

#A partir de aqui al implementar una aplicación en la malla de servicio OpenShift de Red Hat, debe optar por la inyección especificando 
#la "sidecar.istio.io/injectanotación" con un valor de "true". 
#Un ejemplo de un deployment activando la malla de servicio lo podemos encontrar en yaml/example.yaml
#Hasta aqui Istio ya estara desplegado.


#Para acceder a los servicios desplegados en Istio (Kiali, Jaeger, Grafana, Prometheus), ejecutamos

#PROMETHEUS
#Verificamos su despliegue
oc get svc prometheus -n istio-system
#Obtenemos la ruta generada para dicho servicio
export PROMETHEUS_URL=$(oc get route -n istio-system prometheus -o jsonpath='{.spec.host}')
#Ingresamos en 
https://${PROMETHEUS_URL}

#KIALI
#Verificamos su despliegue
oc get svc kiali -n istio-system
#Obtenemos la ruta generada para dicho servicio
export KIALI_URL=$(oc get route -n istio-system kiali -o jsonpath='{.spec.host}')
#Ingresamos en 
https://${KIALI_URL}

#JAEGER
#Verificamos su despliegue
oc get svc jaeger-query -n istio-system
#Obtenemos la ruta generada para dicho servicio
export JAEGER_URL=$(oc get route -n istio-system jaeger-query -o jsonpath='{.spec.host}')
#Ingresamos en 
https://${JAEGER_URL}

#GRAFANA
#Verificamos su despliegue
oc get svc grafana -n istio-system
#Obtenemos la ruta generada para dicho servicio
export GRAFANA_URL=$(oc get route -n istio-system grafana -o jsonpath='{.spec.host}')
#Ingresamos en 
https://${GRAFANA_URL}

