# Restaurantes Brasília iOS

MVP SwiftUI offline-first para descoberta de restaurantes no Distrito Federal.

- Bundle ID: `br.com.restaurantes.bsb`
- App Store ID: `6813989690`
- SKU: `restaurantes-brasilia`
- Projeto gerado com XcodeGen
- Catálogo local, busca, filtros, favoritos e links para telefone/site/mapa

## Desenvolvimento

```bash
xcodegen generate --spec project.yml
xcodebuild test -project RestaurantesBrasilia.xcodeproj -scheme RestaurantesBrasilia -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
python3 tools/jerv_cli.py validate app.yml
```

O release fica bloqueado até a origem e os direitos do catálogo serem revisados.
