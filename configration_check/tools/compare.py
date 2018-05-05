import ConfigParser


def compare_ini(expectancy, actuality, reset_flag=False):
    result = ""
    cf1 = ConfigParser.RawConfigParser(allow_no_value=True)
    cf2 = ConfigParser.RawConfigParser(allow_no_value=True)
    cf1.read(expectancy)
    cf2.read(actuality)
    s1 = cf1.sections()
    for s in s1:
        o1 = cf1.options(s)
        for o in o1:
            v1 = cf1.get(s, o)
            v2 = cf2.get(s, o)
            if v1 != v2:
                result = result + "%s,%s,%s,%s,%s\n" % (actuality, s, o, v1, v2)
                if reset_flag:
                    cf2.set(s, o, v1)
                    cf2.write(open(actuality, "w"))

    return result


def compare_json(expectancy, actuality, reset_flag=False):
    pass
