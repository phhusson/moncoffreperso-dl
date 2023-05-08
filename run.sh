#!/bin/bash


. creds.sh

cleanup() {
    [ -n "$tmpf" ] && rm -f "$tmpf"
    true
}
trap cleanup EXIT
tmpf=$(mktemp)

set -ex

# Get cookies
curl -c cookies -b cookies https://www.moncoffreperso.com/a > /dev/null

curYear="$(date -d '1 week ago' +%Y)"

# Check whether we're already logged
# Is there a login_form when trying to access bulletins?
if curl -b cookies https://www.moncoffreperso.com/documents/bulletin-de-salaire/$curYear -L | pup 'div.login_form' | grep -qE .;then
    curl -b cookies -X POST -d "$LOGIN" -dcf_password="$PASSWORD" -dcf_passNumber="$PASSN" -dcf_connect=Connexion https://www.moncoffreperso.com/login -L
    # This always returns to a 404, I don't know why. And it makes checking whether login succeeded or not annoying
fi

if curl -b cookies https://www.moncoffreperso.com/documents/bulletin-de-salaire/$curYear -L | pup 'div.login_form' | grep -qE .;then
    echo "Login failed"
    exit 1
fi

allYears="$(curl -b cookies https://www.moncoffreperso.com/documents/bulletin-de-salaire/$curYear |grep -oE '/documents/bulletin-de-salaire/20[0-9]{2}' |sort -u |grep -oE '[0-9]{4}$')"
for y in $allYears;do
    curl -b cookies https://www.moncoffreperso.com/documents/bulletin-de-salaire/$y > "$tmpf"

    dates="$(cat "$tmpf" | pup 'tr td[data-order] text{}' | sort -u)"
    for d in $dates;do
        # Change to "data-order" date format, YYYY-MM-DD
        d2="$(echo "$d" |sed -nE 's;([0-9]{2})/([0-9]{4});\2-\1-01;p')"
        d3="$(echo "$d" |sed -nE 's;([0-9]{2})/([0-9]{4});\2-\1;p')"

        links="$(cat "$tmpf" |pup ":parent-of(td[data-order="$d2"]) a attr{href}" | grep /download/)"
        i=1
        for l in $links;do
            curl -b cookies https://www.moncoffreperso.com/$l > Salaire-$d2-$i.pdf
            i=$((i+1))
        done

        # There was only one downloaded file
        if [ "$i" = 2 ];then
            mv -f Salaire-$d2-1.pdf Salaire-$d3.pdf
        # There were two
        elif [ "$i" = 3 ];then
            pdftk Salaire-$d2-2.pdf Salaire-$d2-1.pdf cat output Salaire-$d3.pdf
            rm -f Salaire-$d2-*.pdf
        else
            echo lol
            exit 1
        fi
    done
done
