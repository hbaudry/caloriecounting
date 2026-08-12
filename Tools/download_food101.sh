#!/usr/bin/env bash
#
# Télécharge et décompresse le jeu de données Food-101 (~5 Go).
# Résultat : dossier ./food-101/images/<classe>/*.jpg (101 classes)
#
set -euo pipefail

URL="http://data.vision.ee.ethz.ch/cvl/food-101.tar.gz"
ARCHIVE="food-101.tar.gz"

if [ -d "food-101/images" ]; then
  echo "food-101/images existe déjà — rien à faire."
  exit 0
fi

echo "Téléchargement de Food-101 (~5 Go)…"
curl -L -o "$ARCHIVE" "$URL"

echo "Décompression…"
tar -xzf "$ARCHIVE"

echo "Terminé. Images dans : food-101/images"
echo "Vous pouvez supprimer $ARCHIVE."
