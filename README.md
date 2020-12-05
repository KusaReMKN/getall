# GetAll

ウェブページ全部持ってきちゃえ！

# GetAll is なに

**GetAll** を利用してウェブページにリンクされたページを再帰的に取得することができます．
ウェブサイトの全てのページが相互にリンクされていれば，GetAll を利用してそのウェブサイトの上の全てのページをダウンロードできるでしょう．

# Installation

## on Linux

以下を実行すると実行ファイル `getall` ができます．

```
$ git clone https://github.com/KusaReMKN/getall.git
$ cd getall
$ make
```

インストールするには以下を実行します．
デフォルトでは `$HOME/bin` にインストールされます．

```
$ make install
```

インストール先を変更したい場合は `make install` を実行する際に，例えば `DEST=/usr/bin` のように指定してください．

```
$ make install DEST=/usr/bin
```

## on Windows

Windows Subsystem for Linux (WSL) を利用してください．
WSL での操作は Linux と同様です．

# How to Use

```
getall [Options] URL [Path]
```

- **`URL`**: ウェブサイトを取得する起点となるページの URL を指定します．
  `http` から始まる必要があります．
  典型的な例では `http://example.com/` や `https://KusaReMKN.github.io/` のようにウェブサイトのルートを指定します．

- **`Path`**: 取得したウェブページを保存するディレクトリを指定します．
  ディレクトリは存在している必要があります．
  省略した場合はカレントディレクトリが選択されます．

## Options

- **`-h`**, **`--help`**: ヘルプメッセージを出力して終了します．
- **`-v`**, **`--version`**: バージョン情報を表示して終了します．

+ **`--auto-suffix`**: 拡張子を持たないファイルに適当な拡張子を付与します．
+ **`--force-suffix`**: あらゆるファイルに適当な拡張子を付与します．

GetAll は `URL` で指定されたオリジンと同じオリジンにあるコンテンツのみを取得しようと試みます (これはとても大雑把な表現です)．
例えば，`http://foo.com/` のページから `http://bar.com/` へのリンクが検出されても，`http://bar.com/` の内容を取得しません．


# LICENSE

MIT
