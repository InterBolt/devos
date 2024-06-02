PLUGIN EXECUTABLE SPECIFICATION
================================

This document specifies the design and expected behavior of plugin executables used in our software environment.

1. OVERVIEW
-----------
Plugin executables play two primary roles in our system:
1. Collecting data and storing it in a temporary JSON file (collection set).
2. Processing data from the main collection log to produce chunk files.

2. EXECUTION OUTPUT
-------------------
- Plugin executables may output a delay value to stdout, representing the number of seconds to wait before their next execution.
- The delay value should appear as the last line in the executable's stdout.

3. COMMAND-LINE ARGUMENTS
-------------------------
Executables must accept the following command-line arguments:
- `--output-file <path>`: Specifies the path for the collection set file where data should be stored temporarily.
- `--mode <collect|process>`:
  - `collect`: Collects data and writes it to the set file.
  - `process`: Reads from `collection.log` and processes data to create chunk files.

4. COLLECTION SET FILE FORMAT
-----------------------------
When running in `collect` mode, executables must create a JSON file at the path provided by `--output-file`. Each JSON object in this file should follow this structure:
```
{
  "id": number,
  ...custom_fields
}
```
- The `id` field should be a unique numerical identifier.
- The object can include additional custom fields as required.

Before merging the contents of the set file into the main `collection.log`, the bash script will validate that the JSON structure conforms to the specified format.

5. PROCESSING COLLECTION LOG
----------------------------
When running in `process` mode, executables must read data from `collection.log`, process it, and produce one or more JSON chunk files. Each JSON object in the chunk files should follow this structure:
```
{
  "id": number,
  "metadata": {
    ...custom_metadata
  },
  ...custom_fields
}
```
- The `id` field should be a unique numerical identifier.
- The `metadata` field should contain additional metadata relevant to the entry.
- Additional custom fields can be included as needed.

6. EXAMPLE USAGE
----------------
To collect data:
```
example_plugin --mode collect --output-file /tmp/tmp_setfile.json
```

To process data:
```
example_plugin --mode process --output-file /tmp/tmp_setfile.json
```

7. ERROR HANDLING AND LOGGING
-----------------------------
- Executables must produce valid JSON structures as described.
- Any errors encountered should be logged to stderr.
- If an error occurs, the executable should return a non-zero exit code to indicate failure.

8. DELAY MECHANISM
------------------
- The delay value (in seconds) before the next execution should be the last line in the executable's standard output.
- If no valid delay value is provided, the default delay is set to 30 seconds.

9. BEST PRACTICES
-----------------
- Ensure each JSON object in the set file has a unique `id` to prevent conflicts during merging.
- Validate data before writing to the set file to ensure it conforms to the specified structure.
- Implement internal logging for better tracking and debugging.

10. INTEGRATION WITH THE BASH SCRIPT
------------------------------------
- The bash script will provide the output file path and mode as arguments to the executables.
- The script monitors the output for delay values and handles retries upon execution failure, up to a specified maximum number of retries.

By adhering to this specification, the executables will seamlessly integrate into our system, ensuring consistent and reliable data collection and processing.

For questions or additional support, please contact the development team.