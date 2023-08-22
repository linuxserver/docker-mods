def has_key_with_value(dictionary, key, value):
    return key in dictionary and dictionary[key] == value


def merge_dicts(*dict_args):
    result = {}
    for dictionary in dict_args:
        result.update(dictionary)
    return result


def write_file(filename, content):
    with open(filename, 'w+') as file:
        file.write(content)


def read_file(filename):
    with open(filename, 'r') as file:
        content = file.read()
    return content
