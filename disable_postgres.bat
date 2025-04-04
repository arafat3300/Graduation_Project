@echo off
echo Disabling PostgreSQL Firewall Rule...
netsh advfirewall firewall set rule name="PostgreSQL-Local" new enable=no
echo PostgreSQL connections are now blocked.
pause 