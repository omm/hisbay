/*
 The MIT License (MIT)
 Copyright (c) 2012 Lorenzo Fiorini lorenzo.fiorini@gmail.com

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 associated documentation files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute,
 sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
 is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @(#)htmldoc.prg
 *
 * @author      Lorenzo Fiorini
 */


class HtmlDoc

   var cHtmlPage
   var Cargo

   method init
   method write
   method flush

   method head
   method end

endclass

method init() class HtmlDoc

   ::cHtmlPage := ""

   return this

method flush() class HtmlDoc

   return ::cHtmlPage

method write( cString ) class HtmlDoc

   ::cHtmlPage += cString + _CRLF

   return this

method head( hOptions ) class HtmlDoc

   ::cHtmlPage += '<?xml version="1.0"' + getHtmlOption( hOptions, 'encoding', ' ' ) + '?>' + _CRLF + ;
                  '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"' + _CRLF + ;
                  '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' + _CRLF + ;
                  '<html xmlns="http://www.w3.org/1999/xhtml">' + ;
                  '<head>' + ;
                  getHtmlTag( hOptions, 'title', 'title' ) + ;
                  getHtmlScript( hOptions ) + ;
                  getHtmlStyle( hOptions ) + ;
                  getHtmlLinkRel( hOptions ) + ;
                  '</head>' + ;
                  '<body ' + ;
                     getHtmlAllOptions( hOptions ) + ;
                  '>'

   return this

method end() class HtmlDoc

   ::cHtmlPage += '</body></html>'

   return this

static function getHtmlTag( xVal, cKey, cDefault )

   local var cVal := ""

   defaultNil( cDefault, "" )

   if ! empty( xVal ) .AND. ! empty( cKey )
      if hb_HHasKey( xVal, cKey )
         cVal := hb_HGet( xVal, cKey )
         hb_HDel( xVal, cKey )
      endif
   endif

   if cVal == ""
      cVal := cDefault
   endif

   if !( cVal == "" )
      cVal := "<" + cKey + ">" + cVal + "</" + cKey + ">"
   endif

   return cVal

static function getHtmlAllTag( hTags, cSep )

   local cVal := ""

   defaultNil( cSep, " " )

   hb_HEval( hTags, { |k| cVal += getHtmlTag( hTags, k ) + cSep } )

   return cVal

static function getHtmlOption( xVal, cKey, cPre, cPost, lScan )

   local cVal := ""

   if !empty( xVal )
      if empty( cKey )
         cVal := xVal
      elseif hb_HHasKey( xVal, cKey )
         cVal := hb_HGet( xVal, cKey )
         if empty( lScan )
            hb_HDel( xVal, cKey )
         endif
         cVal := cKey + '="' + cVal + '"'
         if cPre != NIL
            cVal := cPre + cVal
         endif
         if cPost != NIL
            cVal := cVal + cPost
         endif
      endif
   endif

   return cVal

static function getHtmlAllOptions( hOptions, cSep )

   local var cVal := ""

   if !empty( hOptions )

      defaultNil( cSep, " " )

      hb_HEval( hOptions, { |k| cVal += getHtmlOption( hOptions, k,,, .T. ) + cSep } )

   endif

   return cVal

static function getHtmlValue( xVal, cKey, cDefault )

   local var cVal := ""

   defaultNil( cDefault, "" )

   if !empty( xVal ) .and. !empty( cKey )
      if hb_HHasKey( xVal, cKey )
         cVal := hb_HGet( xVal, cKey )
         hb_HDel( xVal, cKey )
      endif
   endif

   if cVal == ""
      cVal := cDefault
   endif

   return cVal

static function getHtmlAllValues( hValues, cSep )

   local var cVal := ""

   if !empty( hValues )

      defaultNil( cSep, " " )

      hb_HEval( hValues, { |k| cVal += getHtmlValue( hValues, k ) + cSep } )

   endif

   return cVal

static function getHtmlScript( hVal, cKey )

   local var hTmp
   local var cRet := ""
   local var cVal
   local var nPos
   local var cTmp

   defaultNil( cKey, "script" )

   if !empty( hVal )
      if ( nPos := hb_HPos( hVal, cKey ) ) != 0
         hTmp := hb_HValueAt( hVal, nPos )
         if hb_isHash( hTmp )
            if ( nPos := hb_HPos( hTmp, "src" ) ) != 0
               cVal := hb_HValueAt( hTmp, nPos )
               if hb_isChar( cVal )
                  cVal := { cVal }
               endif
               if hb_isArray( cVal )
                  cTmp := ""
                  ascan( cVal, { | cFile | cTmp += '<script src="' + cFile + '" type="text/javascript"></script>' + _CRLF } )
                  cRet += cTmp
               endif
            endif
            if ( nPos := hb_HPos( hTmp, "var" ) ) != 0
               cVal := hb_HValueAt( hTmp, nPos )
               if hb_isChar( cVal )
                  cVal := { cVal }
               endif
               if hb_isArray( cVal )
                  cTmp := ""
                  ascan( cVal, { | cVar | cTmp += cVar } )
                  cRet += '<script type="text/javascript">' + _CRLF + '<!--' + _CRLF + cTmp + _CRLF + '-->' + _CRLF + '</script>' + _CRLF
               endif
            endif
         endif
         hb_HDel( hVal, cKey )
      endif
   endif

   return cRet

static function getHtmlStyle( hVal, cKey )

   local var hTmp
   local var cRet := ""
   local var cVal
   local var nPos
   local var cTmp

   defaultNil( cKey, "style" )

   if !empty( hVal )
      if ( nPos := hb_HPos( hVal, cKey ) ) != 0
         hTmp := hb_HValueAt( hVal, nPos )
         if hb_isHash( hTmp )
            if ( nPos := hb_HPos( hTmp, "src" ) ) != 0
               cVal := hb_HValueAt( hTmp, nPos )
               if hb_isChar( cVal )
                  cVal := { cVal }
               endif
               if hb_isArray( cVal )
                  cTmp := ""
                  AScan( cVal, { | cFile | cTmp += '<link rel="StyleSheet" href="' + cFile + '" type="text/css">' + _CRLF } )
                  cRet += cTmp
               endif
            endif
            if ( nPos := hb_HPos( hTmp, "var" ) ) != 0
               cVal := hb_HValueAt( hTmp, nPos )
               if hb_isChar( cVal )
                  cVal := { cVal }
               endif
               if hb_isArray( cVal )
                  cTmp := ""
                  ascan( cVal, { |cVar| cTmp += cVar } )
                  cRet += '<style type="text/css">' + _CRLF + '<!--' + _CRLF + cTmp + _CRLF + '-->' + _CRLF + '</style>' + _CRLF
               endif
            endif
         endif
         hb_HDel( hVal, cKey )
      endif
   endif

   return cRet

static function getHtmlLinkRel( hVal, cKey )

   local var hTmp
   local var cRet := ""
   local var cVal
   local var nPos
   local var cTmp

   defaultNil( cKey, "link" )

   if !empty( hVal )
      if ( nPos := hb_HPos( hVal, cKey ) ) != 0
         hTmp := hb_HValueAt( hVal, nPos )
         if hb_isHash( hTmp )
            if ( nPos := hb_HPos( hTmp, "rel" ) ) != 0
               cVal := hb_HValueAt( hTmp, nPos )
               if hb_isChar( cVal )
                  cVal := { cVal, cVal }
               endif
               if hb_isArray( cVal )
                  cTmp := ""
                  AScan( cVal, { | aVal | cTmp += '<link rel="' + aVal[1] + '" href="' + aVal[2] + '"/>' + _CRLF } )
                  cRet += cTmp
               endif
            endif
         endif
         hb_HDel( hVal, cKey )
      endif
   endif

   return cRet
