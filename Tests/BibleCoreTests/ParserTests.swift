import Foundation
import Testing
@testable import BibleCore

/// Fixtures imitate the markup of the sources with placeholder text.
struct ParserTests {
    @Test func parsesHTMLIntoParagraphsAndRuns() {
        let html = """
        <p>Первый <strong>жирный</strong> и <em>курсив</em>&nbsp;&laquo;цитата&raquo;.</p>
        <p>Ссылка: <span class='bg_bibrefs'><a href='https://azbyka.ru/biblia/?1Cor.1:13' target='_blank'>1Кор.1:13</a></span>
        и <a href="https://example.com/page">сайт</a>.</p>
        <script>ignored()</script><!-- comment -->
        """
        let text = HTMLText.parse(html)
        #expect(text.paragraphs.count == 2)
        let first = text.paragraphs[0]
        #expect(first.plainText == "Первый жирный и курсив\u{00A0}«цитата».")
        #expect(first.runs.contains { $0.text == "жирный" && $0.style == .bold })
        #expect(first.runs.contains { $0.text == "курсив" && $0.style == .italic })

        let second = text.paragraphs[1]
        let bible = second.runs.first { $0.text == "1Кор.1:13" }
        #expect(bible?.link == .bible(VerseRange(VerseRef(book: 46, chapter: 1, verse: 13))))
        let web = second.runs.first { $0.text == "сайт" }
        #expect(web?.link == .web(URL(string: "https://example.com/page")!))
        #expect(!text.plainText.contains("ignored"))
    }

    @Test func parsesLexiconArticle() {
        let html = "<el>λόγος</el> <br/>слово, речь; <br/><df>Этимология:</df> от <a href=S:G3004>G3004</a>"
        let text = HTMLText.parse(html)
        #expect(text.paragraphs.count == 1)
        let runs = text.paragraphs[0].runs
        #expect(runs.first?.style == .original)
        #expect(runs.contains { $0.style == .label && $0.text.contains("Этимология") })
        #expect(runs.contains { $0.link == .strong("G3004") && $0.text == "G3004" })
        #expect(text.plainText.contains("\n"))
    }

    @Test func decodesEntities() {
        #expect(HTMLText.decodeEntities("A&amp;B &#1040; &#x416; &mdash; &unknown; &") == "A&B А Ж — &unknown; &")
    }

    @Test func splitsStrongTaggedText() {
        let greek = "οὕτως<S>3779</S> γὰρ<S>1063</S> ἠγάπησεν<S>25</S> ὁ<S>3588</S> θεὸς<S>2316</S> τὸν<S>3588</S> κόσμον,<S>2889</S>"
        let words = OriginalText.words(fromTagged: greek, language: .greek)
        #expect(words.count == 7)
        #expect(words[0].text == "οὕτως")
        #expect(words[0].numbers == [StrongNumber(language: .greek, number: 3779)])
        #expect(words[6].text == "κόσμον,")
        #expect(words[6].bareText == "κόσμον")

        let hebrew = "בְּרֵאשִׁ֖ית<S>7225</S> בָּרָ֣א<S>1254</S><S>9999</S> untagged אֱלֹהִ֑ים<S>430</S><br>"
        let hebrewWords = OriginalText.words(fromTagged: hebrew, language: .hebrew)
        #expect(hebrewWords.map(\.text) == ["בְּרֵאשִׁ֖ית", "בָּרָ֣א", "untagged", "אֱלֹהִ֑ים"])
        #expect(hebrewWords[1].numbers.map(\.description) == ["H1254", "H9999"])
        #expect(hebrewWords[2].numbers.isEmpty)
    }

    @Test func parsesStrongNumbers() {
        #expect(StrongNumber("G3056")?.description == "G3056")
        #expect(StrongNumber("h07225")?.description == "H7225")
        #expect(StrongNumber("X1") == nil)
        #expect(StrongNumber("G") == nil)
    }

    @Test func parsesAzbykaVerses() {
        let html = """
        <ul><li id="lang-b"><a class="load-translation" data-lang-code="b">Рус. (еп. Кассиан)</a></li></ul>
        <div data-lang="b" data-chapter="3" data-line="1" data-verse="Jn.3:1" class="verse lang-b line-1 col-1 ">Первый стих.<span class="icon-check checkbox"></span> </div>
        <div data-lang="b" data-chapter="3" data-line="2" data-verse="Jn.3:2" class="verse lang-b line-2 col-1 ">Второй <i>стих</i>.<span class="icon-check checkbox"></span> </div>
        <div data-lang="b" data-chapter="4" data-line="1" data-verse="Jn.4:1" class="verse lang-b line-1 col-1 ">Другая глава.</div>
        """
        let verses = Azbyka.parseVerses(html: html, chapter: 3)
        #expect(verses == [Verse(number: 1, text: "Первый стих."), Verse(number: 2, text: "Второй стих.")])
    }

    @Test func parsesAzbykaCommentaries() throws {
        let html = """
        <html><body>
        <div class="interpretation"> <h2 id="avtor-pervyy"> Автор Первый, свт. (†407) <span data-url="x" class="btn-title-link-copy icon-copy" data-copied-label="скопировано!"></span>
        <span class="favorite no-fav" data-label="Ин.3:16 Автор"> <span class="tag-container"></span> <span class="comment"></span> </span> </h2>
        <div class="interp-content"> <p>Ст. 16 <strong>Текст стиха</strong></p> <p>Толкование со ссылкой (<a href='https://azbyka.ru/biblia/?1Cor.1:13'>1Кор.1:13</a>).</p> </div>
        <p class="interp-src"><a class="interp-src__link" target="_blank" href="https://azbyka.ru/otechnik/avtor/trud/27">Беседы</a></p> </div>
        <div class="interpretation"> <h2 id="vtoroy"> Второй автор </h2>
        <div class="interp-content"> <p>Короткое толкование.</p> </div>
        <p class="interp-src"><a class="interp-src__link" href="">Без ссылки</a></p> </div>
        <div class="interpretation"></div>
        <div class="container bottom-menu-container"></div>
        </body></html>
        """
        let page = URL(string: "https://azbyka.ru/biblia/in/?Jn.3:16")
        let items = Azbyka.parseCommentaries(html: html, pageURL: page)
        #expect(items.count == 2)
        let first = try #require(items.first)
        #expect(first.id == "avtor-pervyy")
        #expect(first.author == "Автор Первый, свт.")
        #expect(first.lifetime == "†407")
        #expect(first.text.paragraphs.count == 2)
        #expect(first.sourceTitle == "Беседы")
        #expect(first.sourceURL?.absoluteString == "https://azbyka.ru/otechnik/avtor/trud/27")
        #expect(first.pageURL?.absoluteString == "https://azbyka.ru/biblia/in/?Jn.3:16#avtor-pervyy")
        #expect(first.text.paragraphs[1].runs.contains { $0.link == .bible(VerseRange(VerseRef(book: 46, chapter: 1, verse: 13))) })

        let second = items[1]
        #expect(second.author == "Второй автор")
        #expect(second.lifetime == nil)
        #expect(second.sourceURL == nil)
        #expect(second.sourceTitle == "Без ссылки")
    }
}
