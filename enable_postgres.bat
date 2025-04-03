@echo off
echo Enabling PostgreSQL Firewall Rule...
netsh advfirewall firewall set rule name="PostgreSQL-Local" new enable=yes
echo PostgreSQL connections are now allowed.
pause 