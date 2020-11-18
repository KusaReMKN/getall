#!/bin/sh

GETTER=GET
HEADER=HEAD

# Content-Type そのものの値を返す
# ContentTypeOf(URI)
ContentTypeOf() {
  [ $# -eq 1 ] \
    && $HEADER $1 \
    | sed -Ene 's/^[Cc]ontent-[Tt]ype:\s*(.*).*$/\1/p'
}

# Content-Type の中の MIME を返す
# MIMETypeOf(URI)
MIMETypeOf() {
  echo $(ContentTypeOf $1) \
    | sed -En -e 's/^([^;]*).*$/\1/p'
}

# / で終わるファイルには index.html を付与
# AutoIndex([URI])
AutoIndex() {
  echo $1 \
    | sed -E -e 's#(.*)/$#\1/index.html#'
}

# ベース URL を返す
# BaseURI(File, [Default])
BaseURI() {
  if [ -f "$1" ]; then
    base=$(sed -Ene 's/.*<base.*href="([^"]+)".*>.*/\1/pi' "$1")
    if [ -n "$base" ]; then
      echo $base
    else
      echo $2
    fi
  fi
}

# 完全修飾 URL からファイル名部分を取り去ったディレクトリを返す
# DirURI([URI])
DirURI() {
  echo "$(echo $1 | sed -E -e 's#([^/])/[^/]*$#\1#')/"
}

# 完全修飾 URL からその親ディレクトリを指す URL を返す
# ParentDirURI([URI])
ParentDirURI() {
  echo "$(DirURI $(DirURI $1 | sed -E -e 's#/$##'))"
}
