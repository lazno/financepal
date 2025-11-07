import domain/common_types.{isin}
import gleeunit/should
import rest/client/yahoo

pub fn fetch_price_from_yahoo_test() {
  yahoo.fetch_price_from_yahoo(isin("US88160R1014"))
  |> should.be_ok()
}
