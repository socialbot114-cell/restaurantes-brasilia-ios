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

## Revisão visual de fotos

O workflow **Restaurantes Brasília photo visual review** compila o app e executa um teste de UI no iPhone 17 e em um simulador de iPad disponível no runner. Ele captura início, busca, detalhe com foto Duo Gourmet, lista Explorar, detalhe Verona/Tripadvisor e Favoritos. Também decodifica os 240 assets e gera contact sheets para inspeção visual.

Para iniciar manualmente, abra **GitHub → Actions → Restaurantes Brasília photo visual review → Run workflow**. Baixe os artefatos `restaurantes-brasilia-photo-review-iphone` e `restaurantes-brasilia-photo-review-ipad`; abra `index.html` em cada artefato para revisar as telas e as contact sheets. O workflow também roda quando assets, catálogo, UI ou o teste visual mudam.
