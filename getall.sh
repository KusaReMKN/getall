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
