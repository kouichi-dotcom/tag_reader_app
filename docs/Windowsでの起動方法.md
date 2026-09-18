# Windows での起動方法（Windows デスクトップ / Android 画面）

PC（Windows）上でアプリを動かすときの **2 通り**をまとめる。

| 方法 | コマンド | Windows 上に出るもの | 用途 |
|------|----------|----------------------|------|
| **A. Windows デスクトップ** | `flutter run -d windows` | Flutter の Windows ウィンドウ | UI・API 連携の確認（RFID 実機は不可） |
| **B. Android エミュレータ** | エミュレータ起動後に `flutter run -d android` | **Android の画面**（仮想端末） | スマホ向けレイアウト・Android 挙動の確認 |

共通の作業ディレクトリ:

```powershell
cd C:\dev\tag_reader_app
```

利用可能なデバイス一覧:

```powershell
flutter devices
```

---

## A. Windows デスクトップとして起動する

`flutter run -d windows` は **Windows 用にビルドした Flutter アプリ**を起動する。  
出てくるのは OS 標準のデスクトップウィンドウであり、Android の端末画面ではない。

```powershell
flutter pub get
flutter run -d windows
```

ビルド済み exe だけ起動する場合（再ビルドしない）:

```text
C:\dev\tag_reader_app\build\windows\x64\runner\Debug\tag_reader_app.exe
```

### 向いていること / 向いていないこと

- ○ UI 操作、API（TagReaderApi）との疎通
- × TSS RFID / Bluetooth タグリーダー連携（Android / iOS ネイティブ実装が必要）

---

## B. Android の画面を Windows 上に表示する（エミュレータ）

Android 向けビルドを **エミュレータ（仮想 Android 端末）** で動かすと、Windows 上に **Android の画面**が表示される。

### 1) エミュレータ（AVD）の準備

初回のみ。Android Studio で行う。

1. Android Studio を起動
2. **Tools → Device Manager**（または Welcome 画面の More Actions → Virtual Device Manager）
3. **Create Device** で端末（例: Pixel 6 / Medium Phone）を選ぶ → **Next**
4. **システムイメージを選んでダウンロードし、AVD を作成する**（詳細は下記）
5. **▶ でエミュレータを起動する**（詳細は下記）

#### 手順 4 の詳細（システムイメージの選択・ダウンロード・AVD 作成）

「Create Device」の次の画面が **System Image**（システムイメージ）選択です。ここに並ぶのが、仮想端末に入れる **Android OS のバージョン**です。

1. 画面上部のタブを確認する  
   - **Recommended** … 推奨イメージ（まずここから選ぶ）  
   - **x86 Images** / **Other Images** … 別アーキテクチャや古い API など
2. 行を 1 つ選ぶ（例）  
   - **API Level**: 34（Android 14）や 36 など。数字が大きいほど新しい OS  
   - **ABI**: PC が Intel/AMD なら通常 **x86_64**（または一覧に出る推奨行）  
   - **Target**: 例 `Google APIs` / `Google Play`（Play ストア付きが欲しい場合は Google Play）
3. 選んだ行の右に **Download** リンクが出ていればクリックする  
   - ライセンス同意 → ダウンロード完了まで待つ（初回は数 GB になることがある）  
   - 既に入っているイメージは Download が出ず、そのまま選べる
4. ダウンロード済みの行を選択した状態で **Next**
5. **AVD の確認画面（Android Virtual Device）**  
   - **AVD Name**: 好きな名前（例: `Medium_Phone_API_36`）。後から `emulator -list-avds` に出る名前  
   - 解像度・向きはそのままでよい（必要なら後から Device Manager で編集可）  
   - **Finish** で AVD が Device Manager の一覧に追加される

この PC の例: Device Manager / Cursor 上で **「Medium Phone API 36.1」** のように表示される仮想端末。

#### 手順 5 の詳細（エミュレータの起動）

AVD が一覧にあれば、毎回 Create し直す必要はない。

1. Android Studio の **Device Manager** を開く
2. 使いたい AVD の行の右側にある **▶（Run）** をクリック
3. 起動完了まで待つ（初回は数十秒〜数分かかることがある）
4. 表示のされ方は環境による  
   - **別ウィンドウ**: 独立したエミュレータウィンドウで Android ホーム画面が出る  
   - **Cursor / VS Code 内**: 「Medium Phone API 36.1」などのタブで、エディタ横に端末画面が埋め込まれることもある
5. ホーム画面やロック解除まで進めば、エミュレータ準備完了  
   → 続けて「2) Flutter から Android 向けに実行」へ

起動に失敗する場合の確認ポイント:

- PC の仮想化（Intel VT-x / AMD-V）が BIOS で有効か
- Windows の「Windows の機能」で **Hyper-V** / **Windows ハイパーバイザー プラットフォーム** まわりが、Android Emulator の要件と矛盾していないか（環境により必要な設定が異なる）
- Device Manager で Cold Boot Now（冷起動）を試す

#### システムイメージダウンロード失敗: `Not in GZIP format`

Add Device で Finish したあと、次のようなエラーになることがある。

```text
An error occurred while preparing SDK package ... System Image: Not in GZIP format.
```

意味: ダウンロードしたファイルが壊れている（途中切断、プロキシ／セキュリティソフトが HTML エラーページを返した、など）。ZIP として解けない状態。

**まず確認:** すでに使える AVD があるなら、新規作成は不要。

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -list-avds
# この PC の例: Medium_Phone_API_36.1 があれば、それを起動すればよい
```

**API 34 などをどうしても入れたい場合のやり直し手順:**

1. 失敗ダイアログは **Finish** / **Cancel** で閉じる（作成は完了していない）
2. Android Studio → **Settings → Languages & Frameworks → Android SDK → SDK Tools**  
   または **SDK Platforms** から、失敗したイメージを一度外して Apply（残骸削除）
3. 一時ファイルを消す（Android Studio を終了してから）

```powershell
Remove-Item -Recurse -Force "$env:TEMP\PackageOperation*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Android\Sdk\.temp\*" -ErrorAction SilentlyContinue
# 壊れた途中インストールが残っている場合のみ:
# Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Android\Sdk\system-images\android-34\google_apis" -ErrorAction SilentlyContinue
```

4. コマンドラインで再インストール（GUI より失敗しにくいことが多い）

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --install "system-images;android-34;google_apis;x86_64"
```

`cmdline-tools\latest` が無い場合は、Android Studio の **SDK Tools** で **Android SDK Command-line Tools** を入れてから再実行。

5. 成功したら Device Manager で Add Device をやり直し、今度は既に入っている API 34 を選んで Finish（追加ダウンロードが出ないはず）

コマンドで起動する場合（AVD 名は環境により異なる）:

```powershell
# AVD 一覧
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -list-avds

# この PC の例（既にある場合）
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_36.1
```

### 2) Flutter から Android 向けに実行

エミュレータ起動後:

```powershell
flutter devices
# 例: emulator-5554 • sdk gphone64 x86_64 • android-x64

flutter run -d android
# またはデバイス ID を指定
# flutter run -d emulator-5554
```

Windows 上のエミュレータウィンドウ内に、アプリの **Android UI** が表示される。

### 3) API への接続先（エミュレータ時）

エミュレータから見た「この PC」は `localhost` ではなく **`10.0.2.2`** になる。

- 例: PC 上の API が `http://localhost:5262` なら、アプリ側 baseUrl は  
  `http://10.0.2.2:5262`  
  （`lib/config/api_config.dart` の `kApiBaseUrl` を参照・変更）

### 向いていること / 向いていないこと

- ○ スマホ向けレイアウト、Android 固有の画面・権限まわりの確認
- △ Bluetooth / タグリーダー実機連携はエミュレータでは基本不可 → **実機**が必要（[タグリーダー実機テスト手順](タグリーダー実機テスト手順.md)）

---

## よくある取り違え

| やりたいこと | 使う方法 |
|--------------|----------|
| PC で手早く UI を見たい | **A** `flutter run -d windows` |
| **Android の見た目・挙動**を PC 上で見たい | **B** エミュレータ + `flutter run -d android` |
| タグリーダー実機で読取したい | USB 接続した **Android 実機** + `flutter run -d android` |

`flutter run -d windows` だけでは、Android 端末画面は出ない。
