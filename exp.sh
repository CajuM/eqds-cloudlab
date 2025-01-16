#!/bin/sh

ENV=$1

./exp1.sh --testbed-h1 testbed1 --testbed-h2 testbed2 --env ${ENV} --stacks-h1 "ndpip f_stack mtcp" --stacks-h2 "linux" --reboot
./exp1.sh --testbed-h1 testbed2 --testbed-h2 testbed1 --env ${ENV} --stacks-h1 "linux" --stacks-h2 "ndpip f_stack mtcp" --reboot

./exp1.sh --testbed-h1 testbed1 --testbed-h2 testbed1 --env ${ENV} --stacks-h1 "ndpip f_stack mtcp" --stacks-h2 "ndpip f_stack mtcp" --reboot
./exp1.sh --testbed-h1 testbed2 --testbed-h2 testbed2 --env ${ENV} --stacks-h1 "linux" --stacks-h2 "linux" --reboot


./exp2.sh --testbed-h1 testbed1 --testbed-h2 testbed2 --env ${ENV} --stacks-h1 "ndpip f_stack mtcp" --stacks-h2 "linux" --reboot
./exp2.sh --testbed-h1 testbed2 --testbed-h2 testbed1 --env ${ENV} --stacks-h1 "linux" --stacks-h2 "ndpip f_stack mtcp" --reboot

./exp2.sh --testbed-h1 testbed1 --testbed-h2 testbed1 --env ${ENV} --stacks-h1 "ndpip f_stack mtcp" --stacks-h2 "ndpip f_stack mtcp" --reboot
./exp2.sh --testbed-h1 testbed2 --testbed-h2 testbed2 --env ${ENV} --stacks-h1 "linux" --stacks-h2 "linux" --reboot
