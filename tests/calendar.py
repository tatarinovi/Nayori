"""CalDAV discovery and failure checks; no real network or credential store."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('caldav_worker', Path(__file__).resolve().parents[1] / 'services/calendar/caldav_worker.py')
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class CalendarTests(unittest.TestCase):
    def test_description_links(self):
        for url in ['https://telemost.360.yandex.ru/j/4757447538', 'https://peregovorka.mos.ru/room/rhmtipa4srrk']:
            self.assertEqual(worker.event_link('Встреча: ' + url), url)
            self.assertEqual(worker.event_link('<a href="' + url + '">Войти</a>'), url)
            self.assertEqual(worker.event_link('Документы https://example.org/doc и (' + url + ').'), url)
        self.assertEqual(worker.event_link('Нет ссылки'), '')
        self.assertEqual(worker.event_link('javascript:alert(1) file:///tmp/a'), '')
        self.assertEqual(worker.event_link('https://example.org/?a=1&amp;b=2'), 'https://example.org/?a=1&b=2')

    def test_empty_account(self):
        self.assertEqual(worker.handle({}), {'events': [], 'error': ''})

    def test_reject_insecure_and_embedded_credentials(self):
        for url in ['http://example.org/dav', 'https://user:pass@example.org/dav']:
            with self.assertRaises(ValueError):
                worker.request(url, 'u', 'p', 'PROPFIND', '')

    def test_discovery(self):
        response = ET.fromstring('<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>/cal/work/</d:href><d:propstat><d:prop><d:resourcetype><c:calendar/></d:resourcetype></d:prop></d:propstat></d:response></d:multistatus>')
        with patch.object(worker, 'request', return_value=response):
            self.assertEqual(worker.calendars('https://example.org/cal/', 'u', 'p'), ['https://example.org/cal/work/'])

    def test_cross_origin(self):
        with self.assertRaises(ValueError):
            worker.same_origin('https://example.org/', 'https://other.org/calendar')

    def test_password_saved_only_after_success(self):
        with patch.object(worker, 'events', side_effect=ValueError('bad response')), patch.object(worker, 'secret') as store:
            with self.assertRaises(ValueError):
                worker.handle({'url': 'https://example.org/', 'user': 'u', 'password': 'private'})
            store.assert_not_called()


if __name__ == '__main__':
    unittest.main()
