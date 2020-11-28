#!/bin/sh

GETTER=GET
HEADER=HEAD

# Content-Type そのものの値を返す
# ContentTypeOf(URI)
ContentTypeOf() {
  [ $# -eq 1 ] \
    && $HEADER "$1" \
    | sed -Ene 's/^content-type:\s*(.*).*$/\1/pi' \
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
  *://*) echo "$2" ;;
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

# http から始まる URI のコンテンツを保存するための適当な名前を返す
# SaveFileName(URI)
SaveFileName() {
  echo "$(RemoveScheme "$(AutoIndex "$1")")"
}

# http から始まる URI のコンテンツを保存するための適当なディレクトリ名を返す
# SaveDirName(URI)
SaveDirName() {
  echo "$(RemoveScheme "$(DirURI "$1")")"
}

# http から始まる URI のコンテンツを取得して適当なディレクトリに保存する
# GetContent(URI)
GetContent() {
  if ! expr "$1" : 'https\?://' > /dev/null; then
    return 1
  fi
  fdir=$(SaveDirName "$1")
  fname=$(SaveFileName "$1")
  mkdir -p "$fdir"
  $GETTER "$1" > "$fname"
  [ -e "$fname" ] && echo "$fname"
}

# HTML ファイルの中からリンクを抽出する
# GetLinkList(HTMLFile, ListFile)
GetLinkList() {
  if [ $# -ne 2 ]; then
    return 1
  fi
  sed -En -e 's/^.*href\s*=\s*"([^#"]*)#?.*".*$/\1/pi' \
          -e 's/^.*src\s*=\s*"([^"]+)".*$/\1/pi' \
      "$1" \
    | sort \
    | uniq \
    >> "$2"
}

# LinkList の URL を解決する
# ResolveLinkList(SourceListFile, ContentURI, TargetListFile)
ResolveLinkList() {
  if [ $# -ne 3 ]; then
    return 1
  fi
  if [ ! -f "$1" ]; then
    return 1
  fi
  base=$(BaseURI "$1" "$2")
  while read line; do
    echo "$(FullURI "$base" "$line")" >> "$3"
  done < "$1"
}

# オリジンのチェック (超簡易)
# IsSameOrigin(URI1, URI2)
IsSameOrigin() {
  origin1=$(echo "$1" | sed -E -e 's#(https?://[^/]*)/.*$#\1#')
  origin2=$(echo "$2" | sed -E -e 's#(https?://[^/]*)/.*$#\1#')
  [ "$origin1" = "$origin2" ]
}

EscapePercent() {
  echo $1 | sed -e 's/%/%%/g'
}

NestIncrease() {
  if [ -z "$nestcount" ]; then
    export nestcount=0
    export gotlist=$(mktemp)
  else
    export nestcount=$(expr "$nestcount" + 1)
  fi
}

NestDecrease() {
  if [ "$nestcount" -eq 0 ]; then
    unset nestcount
    rm -f "$gotlist"
  else
    export nestcount=$(expr "$nestcount" - 1)
  fi
}

# 本編
# GetAll(URI, [Path])
GetAll() {
  prevcd=$(pwd)
  NestIncrease
  [ -n "$2" ] && cd "$2"
  printf "REQUEST\t$(EscapePercent "$1") ... "
  gotfile=$(GetContent "$1")
  if [ "$(echo $?)" -ne 0 ]; then
    echo "$(tput setaf 1)Error.$(tput sgr0)"
    cd "$prevcd"
    NestDecrease
    return 0
  fi
  echo "$1" >> "$gotlist"
  printf "Done.  "
  if [ "$(MIMETypeOf "$1")" != "text/html" ]; then
    echo "Not HTML.  Skip."
    cd "$prevcd"
    NestDecrease
    return 0
  fi
  rellist=$(mktemp)
  GetLinkList "$gotfile" "$rellist"
  abslist=$(mktemp)
  ResolveLinkList "$rellist" "$1" "$abslist"
  rm -f "$rellist"
  printf "$(cat "$abslist" | wc -l) links found.\n"
  while read line; do
    if grep -q "^$line$" "$gotlist"; then
      printf "$(tput setaf 2)ALREADY\t$(EscapePercent "$line")$(tput sgr0)\n"
      continue
    fi
    if IsSameOrigin "$1" "$line"; then
      "$0" "$line"
    else
      printf "$(tput setaf 1)IGNORE\t$(EscapePercent "$line")$(tput sgr0)\n"
    fi
  done < "$abslist"
  rm -f "$abslist"
  cd "$prevcd"
  NestDecrease
}

GetAll "$1" "$2"
