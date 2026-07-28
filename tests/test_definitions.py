import unittest

from dagster import Definitions, materialize

from app.definitions import daily_order_summary, defs


class DefinitionsTest(unittest.TestCase):
    def test_definitions_are_loadable(self) -> None:
        Definitions.validate_loadable(defs)

    def test_sample_asset_materializes(self) -> None:
        result = materialize([daily_order_summary])
        self.assertTrue(result.success)


if __name__ == "__main__":
    unittest.main()
