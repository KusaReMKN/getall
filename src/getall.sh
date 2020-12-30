#!/bin/sh

VERSION="0.1.7"

GETTER='curl -Lfs'
HEADER='curl -LIfs'

DEBUG=

AUTO_SUFFIX=1
FORCE_SUFFIX=

MIME_TYPES='/etc/mime.types'

# MIME に対応する拡張子を返す
# SuffixOf(MIME)
SuffixOf() {
  if [ -z "$1" ]; then
    echo "unknown"
    return
  fi
  suffix=$(sed -e 's/#.*$//' "$MIME_TYPES" \
    | awk "/^$(echo $1 | sed 's#/#\\/#')/ { print \$2 }")
  if [ -n "$suffix" ]; then
    echo "$suffix"
  else
    echo "unknown"
  fi
}
# Content-Type そのものの値を返す
# ContentTypeOf(URI)
ContentTypeOf() {
  [ $# -eq 1 ] \
    && $HEADER "$1" \
    | sed -e 's/\r$//' \
    | sed -ne 's/^content-type:\s*\(.*\).*$/\1/pi' \
    | tac \
    | head -1
}

# Content-Type の中の MIME を返す
# MIMETypeOf(URI)
MIMETypeOf() {
  echo "$(ContentTypeOf "$1")" \
    | sed -ne 's/^\([^;]*\).*$/\1/p'
}

# / で終わるファイルには index.html を付与
# AutoIndex([URI])
AutoIndex() {
  echo "$1" \
    | sed -e 's#\(.*\)/$#\1/index.html#'
}

# ベース URL を返す
# BaseURI(File, [Default])
BaseURI() {
  if [ -f "$1" ]; then
    base=$(sed -ne 's/.*<base.*href="\([^"][^"]*\)".*>.*/\1/pi' "$1" | tac)
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
  echo "$(echo "$1" | sed -e 's#\([^/]\)/[^/]*$#\1#')/"
}

# 完全修飾 URL からその親ディレクトリを指す URL を返す
# ParentDirURI([URI])
ParentDirURI() {
  echo "$(DirURI "$(DirURI "$1" | sed -e 's#/$##')")"
}

# 完全修飾 URL からその Root ディレクトリを指す URL を返す
# RootDirURI([URI])
RootDirURI() {
  echo "$1" \
    | sed -e 's#^\(https\{0,1\}://[^/]*/\).*$#\1#'
}

# 完全修飾 URL のスキームを返す
# SchemeOf([URI])
SchemeOf() {
  echo "$1" \
    | sed -e 's/^\([^:]*\):.*$/\1/'
}

# 基底 URL と部分 URL から完全修飾 URL を返す
# FullURI(BaseURI, PartURI)
FullURI() {
  case "$2" in
  *://*) echo "$2" ;;
    //*) echo "$(SchemeOf "$1"):$2" ;;
    *:*) echo "$2" ;;
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
    && echo "$(echo "$1" | sed -e 's#.*://\(.*\)#\1#')"
}

# http から始まる URI のコンテンツを保存するための適当な名前を返す
# SaveFileName(URI, [MIME])
SaveFileName() {
  orgname=$(RemoveScheme "$(AutoIndex "$1")")
  if [ -n "$FORCE_SUFFIX" ]; then
    echo "$orgname.$(SuffixOf "$2")"
  elif [ -n "$AUTO_SUFFIX" ]; then
    if echo "$(basename "$orgname")" | grep -v '\.' >/dev/null; then
      echo "$orgname.$(SuffixOf "$2")"
    else
      echo "$orgname"
    fi
  else
    echo "$orgname"
  fi
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
  fname=$(SaveFileName "$1" "$(MIMETypeOf "$1")")
  mkdir -p "$fdir"
  $GETTER "$1" > "$fname"
  if [ $(echo $?) -ne 0 ]; then
    rm "$fname"
    return 1
  fi
  echo "$fname"
}

# HTML ファイルの中からリンクを抽出する
# GetLinkList(HTMLFile, ListFile)
GetLinkList() {
  if [ $# -ne 2 ]; then
    return 1
  fi
  sed -e 's/\r\{0,1\}\n/ /g' \
      -e 's/\(<.[^>]*>\)/\n\1\n/g' \
      "$1" \
    | sed -n -e 's/^.*href\s*=\s*"\([^#"]*\)#\{0,1\}.*".*$/\1/pi' \
             -e 's/^.*src\s*=\s*"\([^"]*\)".*$/\1/pi' \
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
  origin1=$(echo "$1" | sed -e 's#\(https\{0,1\}://[^/]*\)/.*$#\1#')
  origin2=$(echo "$2" | sed -e 's#\(https\{0,1\}://[^/]*\)/.*$#\1#')
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
  printf "[$nestcount]\t$(EscapePercent "$1") ... "
  gotfile=$(GetContent "$1")
  if [ "$(echo $?)" -ne 0 ]; then
    echo "$(tput setaf 1)Error.$(tput sgr0)"
    cd "$prevcd"
    NestDecrease
    return 0
  fi
  echo "$1" >> "$gotlist"
  printf "Done.  "
  mimetype=$(MIMETypeOf "$1")
  if [ "$mimetype" != "text/html" ]; then
    echo "Not HTML ($mimetype).  Skip."
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
      [ "$DEBUG" ] && printf "$(tput setaf 2)ALREADY\t$(EscapePercent "$line")$(tput sgr0)\n"
      continue
    fi
    if IsSameOrigin "$1" "$line"; then
      GetAll "$line"
    else
      [ "$DEBUG" ] && printf "$(tput setaf 1)IGNORE\t$(EscapePercent "$line")$(tput sgr0)\n"
    fi
  done < "$abslist"
  rm -f "$abslist"
  cd "$prevcd"
  NestDecrease
}

# バージョンの表示
VersionMessage() {
  echo "GetAll Version $VERSION."
}

HelpMessage() {
  VersionMessage
  echo "Copyright (C) 2020 KusaReMKN."
  echo ""
  echo "Usage: $(tput bold)getall$(tput sgr0) [Options] URL [Path]"
  echo ""
  echo "    URL           The URL of the page from which to get the website."
  echo "                  It MUST start with $(tput bold)http$(tput sgr0)."
  echo "    Path          The directory to save the acquired web pages."
  echo "                  It MUST exist."
  echo ""
  echo "  --no-auto-suffix   Don't Add suffix to the file doesn't have suffix."
  echo "  --auto-suffix      Add suffix to the file doesn't have suffix."
  echo "  --force-suffix     Add suffix to *$(tput bold)ALL$(tput sgr0)* files."
  echo ""
  echo "  -h, --help      Display this message and exit"
  echo "  -v, --version   Display version and exit"
  echo ""
}

# オプションのチェック
while [ "$1" ]; do
  case "$1" in
    --help|-h)
      HelpMessage
      exit 0
      ;;
    --version|-v)
      VersionMessage
      exit 0
      ;;
    --no-auto-suffix)
      AUTO_SUFFIX=
      ;;
    --auto-suffix)
      AUTO_SUFFIX=1
      ;;
    --force-suffix)
      FORCE_SUFFIX=1
      ;;
    --debug)
      DEBUG=1
      ;;
    -*)
      echo "$(tput setaf 1)Unknown Option -- $1$(tput sgr0)" >&2
      echo "Try $(tput bold)getall -h$(tput sgr0) for more information." >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
  shift
done

if [ -z "$1" ]; then
  echo "$(tput setaf 1)ERROR: No URI specified.$(tput sgr0)" >&2
  echo "Try $(tput bold)getall -h$(tput sgr0) for more information." >&2
  exit 1
fi

if ! expr "$1" : 'https\?://' > /dev/null; then
  echo "$(tput setaf 1)ERROR: Invalid URI specified. -- $1$(tput sgr0)" >&2
  echo "Try $(tput bold)getall -h$(tput sgr0) for more information." >&2
  exit 1
fi

GetAll "$1" "$2"
