# -*- coding: utf-8 -*-

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.

from typing import Dict, List, Optional, cast
from urllib.parse import quote
from lxml import html
import requests
import re

from cps import logger
from cps.services.Metadata import MetaRecord, MetaSourceInfo, Metadata

log = logger.create()

HEADERS = {"User-Agent": "Not Evil Browser", "accept-encoding": "gzip"}


class DMSGuild(Metadata):
    __name__ = "DMSGuild"
    __id__ = "dmsguild"
    DESCRIPTION = "DM's Guild"
    META_URL = "https://www.dmsguild.com"
    BASE_URL = f"{META_URL}/includes/ajax/search_autocomplete_jquery.php?term="
    QUERY_PARAMS = "&json=true"
    HEADERS = {"User-Agent": "Not Evil Browser", "accept-encoding": "gzip"}

    def search(self, query: str, generic_cover: str = "", locale: str = "en"):
        if not self.active:
            return None

        title_tokens = list(self.get_title_tokens(query, strip_joiners=False))
        if title_tokens:
            tokens = [quote(t.encode("utf-8")) for t in title_tokens]
            query = "%20".join(tokens)

        matches = _do_dtrpg_search(
            query=f"{self.BASE_URL}{query}{self.QUERY_PARAMS}",
            source=MetaSourceInfo(
                id=self.__id__,
                description=self.DESCRIPTION,
                link=self.META_URL,
            ),
        )

        return matches


class DriveThruRpg(Metadata):
    __name__ = "DriveThruRPG"
    __id__ = "drivethrurpg"
    DESCRIPTION = "DriveThru RPG"
    META_URL = "https://www.drivethrurpg.com"
    BASE_URL = f"{META_URL}/includes/ajax/search_autocomplete_jquery.php?term="
    QUERY_PARAMS = "&json=true"

    def search(
        self, query: str, generic_cover: str = "", locale: str = "en"
    ) -> Optional[List[MetaRecord]]:
        if not self.active:
            return None
        
        title_tokens = list(self.get_title_tokens(query, strip_joiners=False))
        if title_tokens:
            tokens = [quote(t.encode("utf-8")) for t in title_tokens]
            query = "%20".join(tokens)

        matches = _do_dtrpg_search(
            query=f"{self.BASE_URL}{query}{self.QUERY_PARAMS}",
            source=MetaSourceInfo(
                id=self.__id__,
                description=self.DESCRIPTION,
                link=self.META_URL,
            ),
        )

        return matches


def _do_dtrpg_search(query: str, source: MetaSourceInfo) -> List[MetaRecord]:
    try:
        log.info(f"Requesting data from: {query}")
        result = requests.get(
            query,
            headers=HEADERS,
        )
        result.raise_for_status()
    except Exception as e:
        log.warning(e)
        return list()

    # If there are no hits we see a single element being returned with the easiest
    # identifier being the link.
    results_list: list = result.json()
    if len(results_list) == 1 and results_list[0]["link"] == "#":
        log.info("No results found")
        return list()

    # Since we'll go on to do N further requests for more information,
    # we'll cut it off at the first five results here. Any sufficiently well
    # populated search by title should be enough
    results: List[MetaRecord] = list()
    for r in results_list[0:5]:
        assert isinstance(r, dict)
        match = _fetch_dtrpg_search_result(result=r, source=source)

        identifiers = {}
        identifiers[source.id] = match.id

        match.identifiers = identifiers

        results.append(match)

    return results


def _fetch_dtrpg_search_result(result: Dict, source: MetaSourceInfo) -> MetaRecord:
    match = MetaRecord(
        id=result["name"],
        title=result["name"],
        authors=[],
        url=result.get("link", ""),
        source=source,
    )

    try:
        details_result = requests.get(
            result["link"],
            headers=HEADERS,
        )
        details_result.raise_for_status()
    except Exception as e:
        log.warning(e)
        return match

    _parse_dtrpg_result(details_result.content, match)

    return match


def _parse_dtrpg_result(content: bytes, match: MetaRecord):
    AUTHORS_XPATH = "//div[@class='widget-information-wrapper']//div[@class='widget-information-item-title' and contains(text(), 'Author(s)')]"
    RULE_SYSTEMS_XPATH = "//div[@class='widget-information-wrapper']//div[@class='widget-information-item-title' and contains(text(), 'Rule System(s)')]"
    PUBLISHER_XPATH = "//div[@class='widget-information-wrapper-2']//div[@class='widget-information-title' and contains(text(), 'Publisher')]"
    URL_PROP_XPATH = "//meta[@itemprop='url']/@content"
    DESCRIPTION_XPATH = "//div[contains(@class,'prod-content')]//text()"
    IMAGE_PROP_XPATH = "//meta[@itemprop='image']/@content"

    data = html.fromstring(content)

    # Use the big text field as description as the meta tag is very short
    description_field = data.xpath(DESCRIPTION_XPATH)
    assert isinstance(description_field, List)
    if description_field is not None:
        match.description = "".join(description_field).strip()  # type: ignore

    product_url = data.xpath(URL_PROP_XPATH)
    assert isinstance(product_url, List)
    if product_url is not None and len(product_url) > 0:
        match.url = cast(str, product_url[0])

        # We can get a better ID from the URL
        regex = r".*\/product\/(\d+)\/.*"
        matches = re.findall(regex, match.url)
        if len(matches) > 0:
            match.id = matches[0]

    image_url = data.xpath(IMAGE_PROP_XPATH)
    assert isinstance(image_url, List)
    if image_url is not None and len(image_url) > 0:
        # Calibre web doesn't follow redirects and reports some covers as an error
        log.info(f"Cover URL is {image_url[0]}")
        r = requests.head(image_url[0], allow_redirects=True)
        log.info(f"After following redirects, it is {r.url}") 
        match.cover = cast(str, r.url)

    # Find authors
    for div in cast(List, data.xpath(AUTHORS_XPATH)):
        # Just bring in elements that look like they might be authors.
        authors = list(
            filter(
                lambda x: re.match(r"^\w[\w\s]+$", x),
                div.getnext().xpath(".//text()"),
            )
        )
        match.authors = authors

    # Use rule systems as tags
    match.tags = ["RPG"]
    for div in cast(list, data.xpath(RULE_SYSTEMS_XPATH)):
        rule_systems = list(
            filter(
                lambda x: len(x.strip()) > 0,
                div.getnext().xpath(".//text()"),
            )
        )
        match.tags.extend(rule_systems)

    for div in cast(List, data.xpath(PUBLISHER_XPATH)):
        publisher_link = div.getnext().xpath(".//a")
        # Sometimes we get a link, other times it's text in a different element.
        if publisher_link is not None and len(publisher_link) > 0:
            match.publisher = publisher_link[0].text_content().strip()
        else:
            publisher_name = div.getnext().xpath(
                ".//div[@class='widget-information-item-title']"
            )
            match.publisher = publisher_name[0].text_content().strip()

    return match
