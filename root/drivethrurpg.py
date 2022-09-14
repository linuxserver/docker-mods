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

from typing import Dict, List, Optional
from urllib.parse import quote
from lxml import html
import requests
import re

from cps import logger
from cps.services.Metadata import MetaRecord, MetaSourceInfo, Metadata

log = logger.create()


class DriveThruRpg(Metadata):
    __name__ = "DriveThruRPG"
    __id__ = "drivethrurpg"
    DESCRIPTION = "DriveThru RPG"
    META_URL = "https://www.drivethrurpg.com/"
    BASE_URL = "https://www.drivethrurpg.com/includes/ajax/search_autocomplete_jquery.php?term="
    QUERY_PARAMS = "&json=true"
    HEADERS = {"User-Agent": "Not Evil Browser", "accept-encoding": "gzip"}

    AUTHORS_XPATH = "//div[@class='widget-information-wrapper']//div[@class='widget-information-item-title' and contains(text(), 'Author(s)')]"
    RULE_SYSTEMS_XPATH = "//div[@class='widget-information-wrapper']//div[@class='widget-information-item-title' and contains(text(), 'Rule System(s)')]"
    PUBLISHER_XPATH = "//div[@class='widget-information-wrapper-2']//div[@class='widget-information-title' and contains(text(), 'Publisher')]"
    URL_PROP_XPATH = "//meta[@itemprop='url']/@content"
    DESCRIPTION_XPATH = "//div[contains(@class,'prod-content')]//text()"
    IMAGE_PROP_XPATH = "//meta[@itemprop='image']/@content"

    def search(
        self, query: str, generic_cover: str = "", locale: str = "en"
    ) -> Optional[List[MetaRecord]]:
        val = list()
        if self.active:
            title_tokens = list(self.get_title_tokens(query, strip_joiners=False))
            if title_tokens:
                tokens = [quote(t.encode("utf-8")) for t in title_tokens]
                query = "%20".join(tokens)

            try:
                result = requests.get(
                    f"{DriveThruRpg.BASE_URL}{query}{DriveThruRpg.QUERY_PARAMS}",
                    headers=DriveThruRpg.HEADERS,
                )
                result.raise_for_status()
            except Exception as e:
                log.warning(e)
                return None

            # Since we'll do on to do N further requests for more information,
            # we'll cut it off at the first five results here. Any sufficiently well
            # populated search by title should be enough
            for r in result.json()[0:5]:
                assert isinstance(r, dict)
                match = self._parse_search_result(
                    result=r, generic_cover=generic_cover, locale=locale
                )
                val.append(match)
        return val

    def _parse_search_result(
        self, result: Dict, generic_cover: str, locale: str
    ) -> MetaRecord:
        match = MetaRecord(
            id=result["name"],
            title=result["name"],
            authors=[],
            url=result.get("link", ""),
            source=MetaSourceInfo(
                id=self.__id__,
                description=DriveThruRpg.DESCRIPTION,
                link=DriveThruRpg.META_URL,
            ),
        )

        try:
            details_result = requests.get(
                result["link"],
                headers=DriveThruRpg.HEADERS,
            )
            details_result.raise_for_status()
        except Exception as e:
            log.warning(e)
            return match

        data = html.fromstring(details_result.content)

        # Use the big text field as description as the meta tag is very short
        description_field = data.xpath(self.DESCRIPTION_XPATH)
        if description_field is not None:
            match.description = "".join(description_field).strip()

        product_url = data.xpath(self.URL_PROP_XPATH)
        if product_url is not None and len(product_url) > 0:
            match.url = product_url[0]

            # We can get a better ID from the URL
            regex = r".*\/product\/(\d+)\/.*"
            matches = re.findall(regex, match.url)
            if len(matches) > 0:
                match.id = matches[0]

        image_url = data.xpath(self.IMAGE_PROP_XPATH)
        if image_url is not None and len(image_url) > 0:
            match.cover = image_url[0]

        # Find authors
        for div in data.xpath(self.AUTHORS_XPATH):
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
        for div in data.xpath(self.RULE_SYSTEMS_XPATH):
            rule_systems = list(
                filter(
                    # lambda x: re.match(r"^\w[()\w\s]+$", x),
                    lambda x: len(x.strip()) > 0,
                    div.getnext().xpath(".//text()"),
                )
            )
            match.tags.extend(rule_systems)

        for div in data.xpath(self.PUBLISHER_XPATH):
            publisher_link = div.getnext().xpath(".//a")
            # Sometimes we get a link, other times it's text in a different element.
            if publisher_link is not None and len(publisher_link) > 0:
                match.publisher = publisher_link[0].text_content().strip()
            else:
                publisher_name = div.getnext().xpath(
                    ".//div[@class='widget-information-item-title']"
                )
                match.publisher = publisher_name[0].text_content().strip()

        # match.publishedDate = result.get("store_date", result.get("date_added"))
        match.identifiers = {"drivethrurpg": match.id}

        return match
