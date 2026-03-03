# Cloudflare ダイナミック DNS アップデーター

このスクリプトは、実行元マシンの外部IPアドレス(IPv4およびIPv6)を使用して、CloudflareのDNS A/AAAAレコードを自動的に作成または更新する軽量なBashスクリプトです。動的な家庭用回線でセルフホストサービスを運用する場合などに便利です。

`ipify.org` を使用して現在のパブリックIPを取得し、Cloudflare v4 APIと連携してDNSエントリを更新します。既存のレコードを最初に確認するようになっており、変更が不要な場合はスキップしたり、以前に作成したレコード（コメント欄の `dnsupdater` タグで判別）のみを上書きするなど、不慮のデータ損失を防ぐ安全な設計になっています。また、堅牢なIP検証と詳細なAPIエラーロギングの機能も備えています。

## 初期設定

1. **リポジトリをクローン**（またはスクリプトをダウンロード）します:
   ```bash
   git clone https://github.com/khirata/cloudflare-dnsupdate.git
   cd cloudflare-dnsupdate
   chmod +x cloudflare-dns-update.sh
   ```

2. **Cloudflareの認証情報を設定します:**
   スクリプトは `~/.cloudflare` に配置された設定ファイルに依存しています。
   
   まず、テンプレートファイルをホームディレクトリにコピーします:
   ```bash
   cp .cloudflare.tmpl ~/.cloudflare
   ```

3. **ファイルを保護し**、システム上の他のユーザーがAPIトークンを読み取れないようにします:
   ```bash
   chmod 600 ~/.cloudflare
   ```

## Cloudflare API 情報の取得

`~/.cloudflare` 内の変数を入力する必要があります。お好きなエディタ (`nano ~/.cloudflare` など) で開いてください。

### `zone` と `dnshost`
*   `zone`: Cloudflare上のルートドメイン名です（例: `example.com`）。
*   `dnshost`: 更新したい特定のサブドメイン名（またはルートドメイン名）です（例: `home.example.com` または `example.com`）。

### `cloudflare_auth_email`
Cloudflareアカウントへのログインに使用するメールアドレスです。

### `cloudflare_auth_key` (API Token)
セキュリティのため、**Global API Keyは使用しないでください**。代わりに、特定のゾーンのDNSレコードを編集する権限のみを持つ「APIトークン」を生成してください。

1.  [Cloudflare ダッシュボード](https://dash.cloudflare.com/) にログインします。
2.  右上のユーザープロフィールアイコンをクリック -> **My Profile** -> **API Tokens** を選択します。
3.  **Create Token** をクリックします。
4.  一番下までスクロールし、**Create Custom Token** を選択します。
5.  以下のように設定します:
    *   **Token Name:** 例: "DDNS Updater"
    *   **Permissions:** `Zone`、次に `DNS`、次に `Edit` を選択
    *   **Zone Resources:** `Include`、次に `Specific zone`、次に自分の `zone` (例: example.com) を選択
6.  **Continue to summary** をクリックし、**Create Token** をクリックします。
7.  **生成された文字列をコピー**し、`~/.cloudflare` 内の `cloudflare_auth_key` に貼り付けます。

最終的な `~/.cloudflare` は以下のようになります:
```env
# configuration used by cloudflare-dns-update.sh
zone=example.com
dnshost=home.example.com
cloudflare_auth_email=your.email@gmail.com
cloudflare_auth_key=abc123DEF456ghi789...
```

## スクリプトの実行

いつでも手動で実行して、動作を確認することができます:
```bash
./cloudflare-dns-update.sh
```

以下のような出力が表示されます:
```
2026-03-03T11:00:00-0800 Establishing connection as IPv4 (203.0.113.50) and IPv6 (2001:db8::1)
2026-03-03T11:00:01-0800 A: Creating record (203.0.113.50)
2026-03-03T11:00:01-0800 Success: Created ID 1a2b3c4d5e6f
2026-03-03T11:00:02-0800 AAAA: home.example.com is currently set to 2001:db8::1; no changes needed
```

## Cronジョブによる自動化

これをダイナミックDNSソリューションとして運用するには、スクリプトを定期的なスケジュール（毎日など）で自動的に実行するようシステムを設定する必要があります。

crontab エディタを開きます:
```bash
crontab -e
```

ファイルの末尾に以下の行を追加します。パスはスクリプトをクローンした場所に合わせて調整してください:

```cron
# 毎日（深夜0時に）CloudflareのDNS A/AAAAレコードを更新する
0 0 * * * /path/to/your/cloudflare-dnsupdate/cloudflare-dns-update.sh >> /tmp/cloudflare-dns-update.log 2>&1
```

*注意: `>> /tmp/cloudflare-dns-update.log 2>&1` の部分は、cronに標準出力とエラーをローカルユーザーアカウントにメールで送信する代わりにログファイルに追記するよう指示するもので、デバッグがはるかに簡単になります。*
