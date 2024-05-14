# To explain how `jq` works to your friend, you can use these five arbitrary `jq` definitions that demonstrate various aspects of `jq`'s functionality, such as filtering, transforming, and creating JSON data.

# ### 1. Extracting a Specific Field

# This definition shows how to extract a specific field from a JSON object.

# ```jq
# def extract_field:
#  .name;
# ```

# **Usage**: Given a JSON object like `{"name": "John", "age": 30}`, calling `extract_field` will output `"John"`.

# ### 2. Filtering an Array

# This definition demonstrates how to filter an array based on a condition.

# ```jq
# def filter_array:
#  .[] | select(.age > 18);
# ```

# **Usage**: Given an array of objects like `[{"name": "John", "age": 30}, {"name": "Alice", "age": 17}]`, calling `filter_array` will output the objects where `age` is greater than 18.

# ### 3. Transforming Data

# This definition shows how to transform data by adding a new field to each object in an array.

# ```jq
# def add_field:
#  .[] |=. + {"status": "active"};
# ```

# **Usage**: Given an array of objects like `[{"name": "John", "age": 30}, {"name": "Alice", "age": 17}]`, calling `add_field` will add a `"status": "active"` field to each object.

# ### 4. Creating a New JSON Object

# This definition demonstrates how to create a new JSON object from existing data.

# ```jq
# def create_object:
#   {"name":.name, "age":.age};
# ```

# **Usage**: Given a JSON object like `{"name": "John", "age": 30}`, calling `create_object` will output the same object, demonstrating how to construct a new object from existing fields.

# ### 5. Aggregating Data

# This definition shows how to aggregate data by summing up the values of a specific field in an array of objects.

# ```jq
# def sum_ages:
#   reduce.[] as $item (0;. + $item.age);
# ```

# **Usage**: Given an array of objects like `[{"name": "John", "age": 30}, {"name": "Alice", "age": 17}]`, calling `sum_ages` will output `47`, which is the sum of the `age` fields.

# These definitions cover basic operations in `jq` such as extraction, filtering, transformation, creation, and aggregation. They provide a good starting point for understanding how `jq` can manipulate JSON data.

# Citations:

# this should print back the input json
def hello(f):
    f;

