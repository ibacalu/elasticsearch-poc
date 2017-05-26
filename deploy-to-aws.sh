#!/bin/bash

### RECOMMENDED: aws-tools installed on your machine.

# export AWS_ACCESS_KEY_ID=''
# export AWS_SECRET_ACCESS_KEY=''
# export AWS_REGION=''
# export AWS_VPC_ID=''
export AWS_ZONE='a'
export AWS_AMI_ID='ami-6f587e1c'
ENV_NAME='ibacalu-test2'

create_vm() {
  docker-machine -D create \
      --driver amazonec2 \
      --amazonec2-access-key $AWS_ACCESS_KEY_ID \
      --amazonec2-secret-key $AWS_SECRET_ACCESS_KEY \
      --amazonec2-vpc-id $AWS_VPC_ID \
      --amazonec2-region $AWS_REGION \
      --amazonec2-zone $AWS_ZONE \
      --amazonec2-ami $AWS_AMI_ID \
      --amazonec2-instance-type t2.medium \
      ${ENV_NAME}
}

use_instance() {
  docker-machine env ${ENV_NAME}
  eval $(docker-machine env ${ENV_NAME})
}

increase_map_count() {
  docker-machine ssh ${ENV_NAME} sudo sysctl -w vm.max_map_count=262144
}

run_compose() {
  docker-compose up -d
}

update_sg() {
  echo "Trying to add port 9200 and 8280 inbound to SG docker-machine (needs aws tools installed)..."
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 9200 --cidr 0.0.0.0/0 > /dev/null 2>&1
  aws ec2 authorize-security-group-ingress --group-name docker-machine --protocol tcp --port 8280 --cidr 0.0.0.0/0 > /dev/null 2>&1
}

banner() {
  ip=`docker-machine ip ${ENV_NAME}`
  echo "##############################################################################################"
  echo "  You can access the ElasticSearch here: http://$ip:9200"
  echo "  You can access HAProxy Status here: http://$ip:8280"
  echo '  NOTES:'
  echo '      - It might take ~1 minute for the cluster to turn green'
  echo "      - If it's not accessible, you need to manually add the ports to the docker-machine SG"
  echo '      - If you want to run docker commands on the new instance:'
  echo "          'docker-machine env ${ENV_NAME}'"
  echo "          'eval \$(docker-machine env ${ENV_NAME})'"
  echo "      - Check Cluster Health: 'curl http://$ip:9200/_cat/health -u elastic:changeme'"
  echo "      - Check Cluster Nodes:  'curl http://$ip:9200/_cat/nodes -u elastic:changeme'"
  echo "##############################################################################################"
}

run() {
  create_vm
  check=$?
  if (( check )); then
    echo "ERROR: Something went wrong. Please check"
    exit 1
  else
    use_instance
    increase_map_count
    run_compose
    update_sg
    banner
  fi
}

# Check AWS Vars
if [[ $AWS_ACCESS_KEY_ID == '' ]]; then
  echo -n "Enter your AWS_ACCESS_KEY_ID and press [ENTER]: "
  read AWS_ACCESS_KEY_ID
fi
if [[ $AWS_SECRET_ACCESS_KEY == '' ]]; then
  echo -n "Enter your AWS_SECRET_ACCESS_KEY and press [ENTER]: "
  read AWS_SECRET_ACCESS_KEY
fi
if [[ $AWS_REGION == '' ]]; then
  echo -n "Enter your AWS_REGION and press [ENTER]: "
  read AWS_REGION
fi
if [[ $AWS_VPC_ID == '' ]]; then
  echo -n "Enter your AWS_VPC_ID and press [ENTER]: "
  read AWS_VPC_ID
fi

run
