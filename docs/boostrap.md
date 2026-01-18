Usage rapide (Makefile + scripts)
Prérequis

Azure CLI installée (az)

Terraform installée

kubectl installé (pour récupérer le kubeconfig et faire les port-forwards)

Être connecté à Azure :

az login

Structure

Terraform est exécuté dans : terraform/envs/rncp

Les scripts sont dans : scripts/

Le Makefile est à la racine du repo

1) Initialiser Terraform

Depuis la racine du repo :

make tf-init


Optionnel :

make tf-fmt
make tf-validate

2) Plan / Apply / Destroy (avec Azure env auto)

Le provider AzureRM a besoin de variables ARM_*.
Elles sont chargées automatiquement via scripts/azure-env.sh dans les cibles tf-plan, tf-apply, tf-destroy.

make tf-plan
make tf-apply
make tf-destroy

Vérifier que l’Azure env est OK
make azure-env

3) Afficher les outputs Terraform
make outputs

4) Récupérer le kubeconfig AKS

Le kubeconfig est écrit par défaut dans :
~/devops/rncp/kubeconfig

make kubeconfig

5) Accéder aux interfaces (port-forward)
Argo CD

Dans un terminal :

make argocd-forward


URL :

http://localhost:8080

Mot de passe admin initial :

make argocd-pass

Grafana / Prometheus / Alertmanager
make grafana-forward
make prometheus-forward
make alertmanager-forward


Les port-forwards sont bloquants : Ctrl+C pour arrêter.

6) Commande “démo” en 1 shot

Déploie l’infra + récupère kubeconfig + affiche le mot de passe Argo CD + démarre le port-forward Argo CD :

make demo-up


Ensuite :

Argo CD : http://localhost:8080

Username : admin

Password : affiché par demo-up

Variables utiles

Changer l’emplacement kubeconfig :

KUBECONFIG_PATH=~/kubeconfig make kubeconfig


Changer le dossier Terraform :

TF_DIR=terraform/envs/rncp make tf-plan