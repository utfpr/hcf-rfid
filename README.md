# HCF UTFPR — Mobile

Aplicativo Android desenvolvido em Flutter para leitura de tags RFID UHF em campo agrícola. Integra-se aos leitores embutidos do Chainway C72 e do Urovo DT50P (e outros Urovo com UHF integrado), além do leitor Bluetooth Acura BTL2128p, e à API do backend HCF UTFPR para realizar conferências de inventário, rastreamento de itens e consulta de estoque.

---

## Funcionalidades

| Tela | Descrição |
|---|---|
| **Conexão com leitor** | Detecta automaticamente o leitor integrado ao dispositivo (Chainway C72 ou Urovo DT50P e outros Urovo com UHF integrado). Também suporta conexão via Bluetooth com outros modelos de leitores. A configuração é persistida localmente. |
| **Scan (Conferência)** | Lista as conferências disponíveis no backend. Ao iniciar, lê as tags RFID em tempo real usando o gatilho físico do leitor e compara com a lista de EPCs da conferência, mostrando em verde os itens encontrados e em cinza os pendentes. Ao finalizar, envia o resultado do inventário para a API. |
| **Histórico** | Exibe todas as sessões de scan realizadas, com data, quantidade de tags lidas e status de sincronização. Permite visualizar os detalhes de cada sessão (EPC, TID, RSSI, contagem de leituras) com filtro por EPC ou TID, e reenviar uma sessão ao backend. |
| **Busca (Tag Finder)** | Realiza leitura contínua de todas as tags ao redor, ordenando-as por intensidade de sinal (RSSI). Permite selecionar um TID específico do estoque para rastrear uma tag individualmente, exibindo o histórico de RSSI em tempo real. |
| **Configurações** | Permite gerenciar a conexão com o leitor (conectar / reconectar) e ajustar a potência de leitura e escrita (faixa de 5 a 30 dBm para o C72 e de 5 dBm até o máximo do módulo, normalmente 33 dBm, para o Urovo). |

---

## Leitores suportados

| Leitor | Conexão | Gatilho |
|---|---|---|
| **Chainway C72** | Integrado, detectado automaticamente (`Build.MODEL`/`MANUFACTURER`). SDK: `DeviceAPI_ver20230301_release.aar`. | Gatilho da empunhadura / teclas de scan (F1–F5, 293). |
| **Urovo DT50P** (e outros Urovo com UHF integrado, ex.: DT50P Lite, DT610) | Integrado, detectado automaticamente (`Build.MANUFACTURER`/`BRAND` "Urovo"/"UBX" ou modelo "DT50*", mais as classes `android.device.*` da ROM Urovo). SDK oficial: `URFIDLibrary-v2.6.0609.aar` ([UrovoSdkCenter/RFID_Android](https://github.com/UrovoSdkCenter/RFID_Android)). | Gatilho da empunhadura (keyCode 523; 515 no PTT do DT610). Com o app em primeiro plano o gatilho deixa de acionar o leitor de código de barras (`enableScanHead`); os botões laterais continuam lendo código de barras. |
| **Acura BTL2128p** | Bluetooth (pareado previamente). SDK: `Rfid.AsciiProtocol-3.1.0-release.aar`. | Gatilho do próprio leitor. |

Observações sobre o Urovo:

- A leitura usa o modo EPC+TID (TID de 96 bits, 24 caracteres hex), o mesmo formato do C72.
- O build de release usa R8; as regras exigidas pelo SDK da Urovo ficam em [`android/app/proguard-rules.pro`](android/app/proguard-rules.pro).
- Se outro app RFID da Urovo estiver usando o módulo, a inicialização falha e o app segue para a tela de configuração.
- Para diagnosticar no aparelho: `adb logcat -s UrovoReaderWrapper MainActivity` (mostra o modelo detectado e o keyCode de cada tecla).

---

## Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **≥ 3.10.8**  
- Android SDK (API 21+)  
- Dispositivo Android físico recomendado (Chainway C72 ou Urovo DT50P para leitura RFID completa)  
- Emulador Android aceito, mas sem suporte a hardware RFID  
- Backend HCF UTFPR em execução (padrão: `https://beontag.cm.utfpr.edu.br`)

---

## Configuração da URL da API

O endereço do backend é definido em [`lib/services/api_config.dart`](lib/services/api_config.dart):

```dart
const String apiBaseUrl = 'https://beontag.cm.utfpr.edu.br';
```

Para apontar para um backend local:
- **Emulador Android**: use `http://10.0.2.2:<porta>`
- **Dispositivo físico**: use o IP da sua máquina na rede local, ex.: `http://192.168.1.100:<porta>`

---

## Como rodar o projeto

```bash
# 1. Clone o repositório
git clone <url-do-repositorio>
cd hcf-rfid

# 2. Instale as dependências
flutter pub get

# 3. Verifique se há um dispositivo/emulador disponível
flutter devices

# 4. Execute o app em modo debug
flutter run
```

Para selecionar um dispositivo específico:

```bash
flutter run -d <device-id>
```

---

## Gerar APK de release

Execute o comando abaixo na raiz do projeto:

```bash
flutter build apk --release
```

O arquivo gerado fica em:

```
build/app/outputs/flutter-apk/app-release.apk
```

Para instalar diretamente no dispositivo conectado via USB:

```bash
flutter install --release
```

> **Dica:** para gerar um APK por ABI (menor tamanho), use `flutter build apk --split-per-abi --release`. Os arquivos ficam no mesmo diretório com sufixos como `app-arm64-v8a-release.apk`.

---

## Dependências principais

| Pacote | Uso |
|---|---|
| `http` | Comunicação com a API REST do backend |
| `shared_preferences` | Persistência local de configurações e sessões de scan |
| `cupertino_icons` | Ícones auxiliares da UI |
