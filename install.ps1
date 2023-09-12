#!/usr/bin/pwsh

param (
    [string] $domain = 'fuszenecker.eu',
    [string] $cloudnsUrl4,
    [string] $cloudnsUrl6
)

function Write-Step {
    param (
        [string] $text
    )

    Write-Host -ForegroundColor Green $text
}

function Install-Packages {
    Write-Step "Installing packages..."
    sudo apt install curl wget
}

function Install-K3s {
    Write-Step "Installing K3s..."
    curl -sfL https://get.k3s.io | sh -

    Write-Step "Enabling K3s services..."
    sudo systemctl enable k3s

    Write-Step "Enabling K3s services..."
    sudo systemctl start k3s

    Write-Step "Copying Kubernetes config..."
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo setfacl -m u:$(id -un):rw /etc/rancher/k3s/k3s.yaml
    sudo chown $(id -un) ~/.kube/config
}

function Setup-ClouDNS {
    Write-Step "Installing Certificate Manager..."

    sudo setfacl -m u:$(id -un):rwx /etc/systemd/system

    $contentService = @"
[Unit]
Description=Update IP in ClouDNS
Wants=ClouDNS.timer

[Service]
Type=oneshot
ExecStart=/usr/bin/wget -q $cloudnsUrl4
ExecStart=/usr/bin/wget -q $cloudnsUrl6

[Install]
WantedBy=multi-user.target
"@

    Set-Content "/etc/systemd/system/ClouDNS.service" $contentService

    $contentTimer = @"
[Unit]
Description=Update IP address in ClouDNS
Requires=ClouDNS.service

[Timer]
OnBootSec=15min
OnUnitActiveSec=4h
Unit=ClouDNS.service

[Install]
WantedBy=timers.target
"@

    Set-Content "/etc/systemd/system/ClouDNS.timer" $contentTimer

    sudo systemctl daemon-reload

    sudo systemctl enable ClouDNS.service
    sudo systemctl start ClouDNS.service
    sudo systemctl enable ClouDNS.timer
    sudo systemctl start ClouDNS.timer
}

function Install-Helm {
    Write-Step "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

function Install-CertificateManager {
    Write-Step "Installing Certificate Manager..."
    kubectl apply --wait -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

    $content = @"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: robert.fuszenecker@outlook.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - http01:
        ingress:
          class: traefik
"@

    Write-Output $content | kubectl apply --wait -f -
}

function Install-RancherUI {
    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
    helm repo update

    kubectl create namespace cattle-system

    # helm install --wait rancher rancher-stable/rancher `
    #     --namespace cattle-system `
    #     --set hostname=rancher.$domain `
    #     --set bootstrapPassword=admin `
    #     --set ingress.tls.source=letsEncrypt `
    #     --set letsEncrypt.email=robert.fuszenecker@outlook.com `
    #     --set letsEncrypt.ingress.class=traefik

    Write-Host "DOMAIN: " $domain

    helm install --wait rancher rancher `
        --namespace cattle-system `
        --set hostname=rancher.$domain `
        --set bootstrapPassword=admin `
        --set ingress.tls.source=letsEncrypt `
        --set letsEncrypt.email=robert.fuszenecker@outlook.com `
        --set letsEncrypt.ingress.class=traefik
}

function Wait-Keypress { 
    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    Write-Host " OK."
}

Install-Packages

Install-K3s

Setup-ClouDNS

Install-Helm

Wait-Keypress
Install-CertificateManager

Wait-Keypress
Install-RancherUI
