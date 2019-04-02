#!/bin/bash
for i in $(kubectl -n devops-cicd get jobs -o custom-columns=:.metadata.name|grep drone)
do
    kubectl -n devops-cicd delete jobs $i 
    #echo $i
done
