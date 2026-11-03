#!/usr/bin/env bash
# Run the whole RFM pipeline against a MySQL 8+ (or MariaDB 10.6+) database.
#
#   ./run.sh                 # uses database "rfm" on localhost as the current user
#   DB=sales_db ./run.sh     # pick another database
#
# Extra mysql client options (host, user, password) can be passed through
# MYSQL_OPTS, e.g. MYSQL_OPTS="-h 127.0.0.1 -u root -proot" ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

DB="${DB:-rfm}"
MYSQL=(mysql ${MYSQL_OPTS:-} --local-infile=1)

"${MYSQL[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DB\`"

for step in sql/01_load.sql sql/02_eda.sql sql/03_rfm.sql; do
    echo "== $step"
    "${MYSQL[@]}" --table "$DB" < "$step"
done

echo "== sql/04_checks.sql"
"${MYSQL[@]}" --table "$DB" < sql/04_checks.sql
failed=$("${MYSQL[@]}" -N "$DB" < sql/04_checks.sql | awk '$2 != 0' | wc -l)
if [ "$failed" -ne 0 ]; then
    echo "FAILED: $failed check(s) above are non-zero" >&2
    exit 1
fi
echo "All checks passed."
