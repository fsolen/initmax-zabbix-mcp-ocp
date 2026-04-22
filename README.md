# initMAX Zabbix MCP Server - OpenShift Deployment

Bu dizin, [initMAX/zabbix-mcp-server](https://github.com/initMAX/zabbix-mcp-server) projesini OpenShift üzerinde native olarak çalıştırmak için gerekli manifest dosyalarını içerir.

## Özellikler

- **BuildConfig**: GitHub'dan otomatik Docker build
- **ConfigMap**: `config.toml` dinamik olarak güncellenebilir
- **Secret**: Zabbix API token'ları güvenli şekilde saklanır
- **Routes**: MCP (8080) ve Admin Portal (9090) için ayrı route'lar

## Hızlı Başlangıç

```bash
# 1. Secret'ı düzenleyin
vi base/secret.yaml
# ZABBIX_PRODUCTION_TOKEN değerini gerçek Zabbix API token'ınızla değiştirin

# 2. ConfigMap'i düzenleyin  
vi base/configmap.yaml
# Zabbix URL'ini güncelleyin: url = "https://your-zabbix.example.com"

# 3. Route hostname'lerini güncelleyin
vi base/route.yaml
# spec.host değerlerini cluster domain'inize göre ayarlayın

# 4. Deploy edin
chmod +x deploy.sh
./deploy.sh deploy
```

## Dosya Yapısı

```
initmax-zabbix-mcp/
├── deploy.sh              # Deploy/yönetim script'i
├── README.md
└── base/
    ├── kustomization.yaml # Kustomize config
    ├── namespace.yaml     # Project/Namespace
    ├── configmap.yaml     # config.toml (dinamik)
    ├── secret.yaml        # API tokens (şifreli)
    ├── build.yaml         # ImageStream + BuildConfig
    ├── deployment.yaml    # Deployment + Service
    └── route.yaml         # MCP ve Admin route'ları
```

## Yönetim Komutları

```bash
# Deploy/güncelle
./deploy.sh deploy

# Build başlat
./deploy.sh build

# Durum kontrol
./deploy.sh status

# Log izle
./deploy.sh logs -f

# Secret güncelle (interaktif)
./deploy.sh secret

# ConfigMap düzenle
./deploy.sh config

# Pod restart
./deploy.sh restart

# Tümünü sil
./deploy.sh delete
```

## Konfigürasyon Güncelleme

### ConfigMap (config.toml)
```bash
# Düzenle
oc edit configmap zabbix-mcp-config -n zabbix-mcp-server

# Değişiklikleri uygula
oc rollout restart deployment/zabbix-mcp-server -n zabbix-mcp-server
```

### Secret (API Tokens)
```bash
# Yeni token ile güncelle
oc create secret generic zabbix-mcp-secret \
  --from-literal=ZABBIX_PRODUCTION_TOKEN="your-new-token" \
  --dry-run=client -o yaml | oc apply -n zabbix-mcp-server -f -

# Pod restart
oc rollout restart deployment/zabbix-mcp-server -n zabbix-mcp-server
```

## AI Client Bağlantısı

Deploy tamamlandıktan sonra route URL'ini alın:
```bash
oc get route zabbix-mcp -n zabbix-mcp-server -o jsonpath='{.spec.host}'
```

VS Code / Claude / Codex için örnek config:
```json
{
  "mcpServers": {
    "zabbix": {
      "type": "http",
      "url": "https://zabbix-mcp.apps.cluster.example.com/mcp"
    }
  }
}
```

## Production Önerileri

1. **SealedSecrets veya ExternalSecrets** kullanın
2. **HPA (Horizontal Pod Autoscaler)** ekleyin
3. **NetworkPolicy** ile erişimi kısıtlayın
4. **PodDisruptionBudget** tanımlayın
5. Admin portal için ayrı authentication (OAuth Proxy) düşünün
