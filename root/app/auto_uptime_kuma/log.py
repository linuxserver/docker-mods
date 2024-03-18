class Log:
    prefix: str

    @staticmethod
    def init(prefix):
        Log.prefix = prefix

    @staticmethod
    def info(message):
        print(f"[{Log.prefix}] {message}")
