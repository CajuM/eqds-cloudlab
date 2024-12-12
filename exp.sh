#!/bin/sh

ENV=$1

./exp1.sh --testbed-tx testbed1 --testbed-rx testbed2 --env ${ENV} --stacks-tx "ndpip f_stack mtcp" --stacks-rx "linux" --reboot
./exp1.sh --testbed-tx testbed2 --testbed-rx testbed1 --env ${ENV} --stacks-tx "linux" --stacks-rx "ndpip f_stack mtcp" --reboot

./exp1.sh --testbed-tx testbed1 --testbed-rx testbed1 --env ${ENV} --stacks-tx "ndpip f_stack mtcp" --stacks-rx "ndpip f_stack mtcp" --reboot
./exp1.sh --testbed-tx testbed2 --testbed-rx testbed2 --env ${ENV} --stacks-tx "linux" --stacks-rx "linux" --reboot


./exp2.sh --testbed-tx testbed1 --testbed-rx testbed2 --env ${ENV} --stacks-tx "ndpip f_stack mtcp" --stacks-rx "linux" --reboot
./exp2.sh --testbed-tx testbed2 --testbed-rx testbed1 --env ${ENV} --stacks-tx "linux" --stacks-rx "ndpip f_stack mtcp" --reboot

./exp2.sh --testbed-tx testbed1 --testbed-rx testbed1 --env ${ENV} --stacks-tx "ndpip f_stack mtcp" --stacks-rx "ndpip f_stack mtcp" --reboot
./exp2.sh --testbed-tx testbed2 --testbed-rx testbed2 --env ${ENV} --stacks-tx "linux" --stacks-rx "linux" --reboot
