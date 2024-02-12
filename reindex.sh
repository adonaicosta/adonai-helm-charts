#!/bin/bash

for i in `ls -d */`
do
helm package $i
done 

helm repo index ../adonai-helm-charts --url https://adonaicosta.github.io/adonai-helm-charts

git add .
git commit -sm "reindex $(echo `date`)"
git push

