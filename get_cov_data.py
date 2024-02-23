

import io
from lxml import etree
import requests


headers = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
    "Accept-Language": "zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "Pragma": "no-cache",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Upgrade-Insecure-Requests": "1",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "sec-ch-ua": "^\\^Not_A",
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "^\\^Windows^^"
}

cookies = {
    "OptanonAlertBoxClosed": "2023-10-16T08:12:11.913Z",
    "OptanonConsent": "isGpcEnabled=0&datestamp=Mon+Oct+16+2023+16%3A12%3A11+GMT%2B0800+(China+Standard+Time)&version=202308.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=914753f9-bdeb-497c-848d-ddeed720e61f&interactionCount=1&landingPath=NotLandingPage&groups=C0002%3A0%2CC0004%3A0%2CC0003%3A0%2CC0001%3A1",
    "TWIKISID": "731263e0f80613ae943a88ea377d23a5"
}
url = "https://twiki.amd.com/twiki/bin/view/Gmhubs/Regression_Results_krackan1_cover"
response = requests.get(url, headers=headers, cookies=cookies)

print(response.text)
# print(response)

xpath_html = etree.HTML(response.text)

data = xpath_html.xpath('//div[@class="editTable"]//table')

for i in data:
    if i.xpath('.//th[@class="twikiFirstCol"]/font/text()'):
        #date = i.xpath('.//th[@class="twikiFirstCol"]/font/text()')[0].replace('-', '')
        list = i.xpath('.//th[@class="twikiFirstCol"]/font/text()')[0].split('-')
        yy = list[0]
        mm = list[1].zfill(2)
        dd = list[2].zfill(2)
        date = yy+mm+dd
    else:
        continue
    if i.xpath('.//tr[4]/td[4]/text()'):
        rates_line = i.xpath('.//tr[4]/td[4]/text()')[0]
    else:
        continue
    if i.xpath('.//tr[4]/td[7]/text()'):
        rates_cond = i.xpath('.//tr[4]/td[7]/text()')[0]
    else:
        continue
    if i.xpath('.//tr[4]/td[10]/text()'):
        rates_fsm = i.xpath('.//tr[4]/td[10]/text()')[0]
    else:
        continue
    if i.xpath('.//tr[4]/td[15]/text()'):
        rates_func = i.xpath('.//tr[4]/td[15]/text()')[0]
    else:
        continue
    if i.xpath('.//tr[4]/td[18]/text()'):
        rates_toggle = i.xpath('.//tr[4]/td[18]/text()')[0]
    else:
        continue
    if i.xpath('.//tr[4]/td[22]/text()'):
         changelist = i.xpath('.//tr[4]/td[22]/text()')[0]
    else:
        continue
    dd = changelist + " " + date + " " + rates_line + " " + rates_cond + " " + rates_fsm + " " + rates_func + " " + rates_toggle
    dd = dd.strip()
    print(dd)
    with io.open('krackan1_cond.txt', 'a', encoding='utf-8') as f:
        f.write(dd + u'\n')




# changelist_id = xpath_html.xpath('//td[contains(@bgcolor,"#edf4f9"/@valign,"top"/@class,"twikiTableCol21")]/text()')
# YearMonthDay = xpath_html.xpath('//font[contains(@color='"#ffffff">2023-10-30')]/text()')
# coverage_rate = xpath_html.xpath('//td[contains(@bgcolor,"#edf4f9"/@valign,"top"/@class,"twikiTableCol3")]/text()')

# for changelist_id, YearMonthDay, coverage_rate(changelist_id, YearMonthDay, coverage_rate);
#  print(changelist_id, YearMonthDay, coverage_rate)