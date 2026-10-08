#!/usr/bin/env bash
# Starts PostgreSQL and runs the SQL scripts of every project in numeric order.
# Usage: ./run_all.sh              all projects
#        ./run_all.sh wholesale-net-revenue
set -euo pipefail

if [ "$#" -gt 0 ]; then
  projects=("$@")
else
  projects=(purchasing-data-cleaning wholesale-net-revenue)
fi

docker compose up -d --wait

for project in "${projects[@]}"; do
  echo "################ ${project}"
  for script in "${project}"/sql/0*.sql; do
    echo "=== ${script}"
    docker compose exec -T -w "/repo/${project}" db \
      psql -U postgres -d glaze -v ON_ERROR_STOP=1 -f "sql/$(basename "${script}")"
  done
done
