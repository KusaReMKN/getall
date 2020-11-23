#!/bin/sh

GETTER=GET
HEADER=HEAD

# Content-Type そのものの値を返す
# ContentTypeOf(URI)
ContentTypeOf() {
  [ $# -eq 1 ] \
    && $HEADER "$1" \
    | sed -Ene 's/^[Cc]ontent-[Tt]ype:\s*(.*).*$/\1/p' \
    | tac
}

# Content-Type の中の MIME を返す
# MIMETypeOf(URI)
MIMETypeOf() {
  echo "$(ContentTypeOf "$1")" \
    | sed -En -e 's/^([^;]*).*$/\1/p'
}

# / で終わるファイルには index.html を付与
# AutoIndex([URI])
AutoIndex() {
  echo "$1" \
    | sed -E -e 's#(.*)/$#\1/index.html#'
}

# ベース URL を返す
# BaseURI(File, [Default])
BaseURI() {
  if [ -f "$1" ]; then
    base=$(sed -Ene 's/.*<base.*href="([^"]+)".*>.*/\1/pi' "$1" | tac)
    if [ -n "$base" ]; then
      echo "$base"
    else
      echo "$2"
    fi
  fi
}

# 完全修飾 URL からファイル名部分を取り去ったディレクトリを返す
# DirURI([URI])
DirURI() {
  echo "$(echo "$1" | sed -E -e 's#([^/])/[^/]*$#\1#')/"
}

# 完全修飾 URL からその親ディレクトリを指す URL を返す
# ParentDirURI([URI])
ParentDirURI() {
  echo "$(DirURI "$(DirURI "$1" | sed -E -e 's#/$##')")"
}

# 完全修飾 URL からその Root ディレクトリを指す URL を返す
# RootDirURI([URI])
RootDirURI() {
  echo "$1" \
    | sed -E -e 's#^(https?://[^/]*/).*$#\1#'
}

# 完全修飾 URL のスキームを返す
# SchemeOf([URI])
SchemeOf() {
  echo "$1" \
    | sed -E -e 's/^([^:]*):.*$/\1/'
}

# 基底 URL と部分 URL から完全修飾 URL を返す
# FullURI(BaseURI, PartURI)
FullURI() {
  case "$2" in
    *:*) echo "$2" ;;
    //*) echo "$(SchemeOf "$1"):$2" ;;
     /*) echo "$(FullURI "$(RootDirURI "$1")" "$(echo "$2" | cut -c 2-)")" ;;
    ./*) echo "$(FullURI "$(DirURI "$1")" "$(echo "$2" | cut -c 3-)")" ;;
   ../*) echo "$(FullURI "$(ParentDirURI "$1")" "$(echo "$2" | cut -c 4-)")" ;;
      *) echo "$(DirURI "$1")$2" ;;
  esac
}

# 完全修飾 URL スキーム名を取り払ったものを返す
# RemoveScheme(URI)
RemoveScheme() {
  [ -n "$1" ] \
    && echo "$(echo "$1" | sed -E -e 's#.*://(.*)#\1#')"
}

# http から始まる URI のコンテンツを取得して適当なディレクトリに保存する
# GetContent(URI)
GetContent() {
  if ! expr "$1" : 'https\?://' > /dev/null; then
    return 1
  fi
  fdir=$(RemoveScheme "$(DirURI "$1")")
  fname=$(RemoveScheme "$1")
  mkdir -p "$fdir"
  $GETTER "$1" > "$fname"
}

# これは考え直したほうがいいかもしれない
# HTML の中にあるリンクを重複なく列挙したファイル名を返す
# LinkList(URI)
LinkList() {
  if [ $# -eq 1 ]; then
    if [ "$(MIMETypeOf "$1")" = "text/html" ]; then
      tmpfile=$(mktemp)

      echo "# $1" > $tmpfile
      $GETTER "$1" \
        | sed -En -e 's/^.*href="([^"]+)".*$/\1/p' \
                  -e 's/^.*src="([^"]+)".*$/\1/p' \
        | sort \
        | uniq \
        >> "$tmpfile"

      echo "$tmpfile"
    fi
  fi
}
