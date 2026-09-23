# Controlled marker response scripts

These scripts reproduce the Windows lab scripts validated in Step 3.9. Install on the Windows victim in `C:\Program Files (x86)\ossec-agent\active-response\bin` using administrator permissions. Preserve Windows CRLF line endings for `.cmd` files. The scripts create or remove only the fixed lab marker; they do not isolate the machine.

The create script overwrites the designated marker file. The remove script refuses to delete it if its contents differ from `SOC_SHUFFLE_RESPONSE_TEST`. Neither implements timed reversal or parses the input alert. Use only as separate stateless lab actions.

Call through the Wazuh API with `!soc-marker-create.cmd` or `!soc-marker-remove.cmd`, targeting only agent `001`. See [validation record](../../../docs/build-shuffle.md). Credentials and live webhook URLs are not included.
