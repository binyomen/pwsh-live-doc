using namespace System.Management.Automation

Import-Module -Force $PSScriptRoot\..\docgen

Describe 'TitleToUrlPathSegment' {
    InModuleScope docgen {
        It 'throws on empty input' {
            { TitleToUrlPathSegment '' } | Should -Throw 'Cannot bind argument to parameter ''Title'' because it is an empty string.'
        }

        It 'lowercases input' {
            TitleToUrlPathSegment 'ABcDEf' | Should -Be 'abcdef'
        }

        It 'collapses all spaces and turns them into hyphens' {
            TitleToUrlPathSegment '  hello this   is a title ' | Should -Be 'hello-this-is-a-title'
        }

        It 'handles punctuation like commas' {
            TitleToUrlPathSegment 'hello, it''s me' | Should -Be 'hello,-it''s-me'
            TitleToUrlPathSegment 'this is a  :, and here''s a \' | Should -Be 'this-is-a-colon,-and-here''s-a-backslash'
            TitleToUrlPathSegment 'The well-known variable $?, or status' | Should -Be 'The-well-dash-known-variable-$-question-mark,-or-status'
        }

        It 'spells out invalid characters' {
            TitleToUrlPathSegment '<>:"/\|?*%-' | Should -Be 'left-angle-bracket-right-angle-bracket-colon-quotation-mark-slash-backslash-pipe-question-mark-star-percent-sign-dash'
        }
    }
}
