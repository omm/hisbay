/*
 The MIT License (MIT)
 Copyright (c) 2013 Lorenzo Fiorini lorenzo.fiorini@gmail.com

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
 * @(#)hisbdefs.ch
 *
 * @author      Lorenzo Fiorini
 */

#ifndef HISBDEFS

   #xtranslate true => .t.
   #xtranslate false => .f.

   #xcommand endwhile => end

   #xcommand <type: local, static, private, public> var <*x*> => <type> <x>

   #xtranslate defaultNil( <x>, <d> ) => iif( <x> == nil, <x> := <d>, <x> )
   #xtranslate defaultEmpty( <x>, <d> ) => iif( empty( <x> ), <x> := <d>, <x> )

   #xtranslate public class => class
   #xtranslate public function => function
   #xtranslate private function => static function
   #xtranslate this => Self

   #xtranslate <s>:sqlNumParam( <p>, <n> ) => <s> := strtran( <s>, "?" + hb_ntos( <p> ), iif( <n> == nil, "", hb_ntos( <n> ) ) )
   #xtranslate <s>:sqlCharParam( <p>, <c> ) => <s> := strtran( <s>, "?" + hb_ntos( <p> ), iif( <c> == nil, "''", "'" + <c> + "'" ) )
   #xtranslate <s>:sqlDateParam( <p>, <d> ) => <s> := strtran( <s>, "?" + hb_ntos( <p> ), iif( <d> == nil, "''", "'" + hb_dtoc( <d>, "YYYY-MM-DD" ) + "'" ) )

   #include "hbclass.ch"

   #xtranslate gethKeyOrDefault( <h>, <k>, <v> ) => iif( hb_hHasKey( <h>, <k> ), hb_hGet( <h>, <k> ), <v> )
   #xtranslate gethKeyOrEmpty( <h>, <k> ) => iif( hb_hHasKey( <h>, <k> ), hb_hGet( <h>, <k> ), "" )

   #xcommand textcstream into <v> => #pragma __cstream|<v>+=%s

   #xcommand textcstreaminclude <f> <dummy: into,to> <v> => #pragma __cstreaminclude <f>|<v>+=%s

   #xcommand textstreaminclude <f> <dummy: into,to> <v> => #pragma __streaminclude <f>|<v>+=%s

   #xcommand strsubst <var> with <value> into <content> => <content> := strtran( cContent, <"var">, <value> )

   #xcommand strjssubst <var> with <value> into <content> => <content> := strtran( <content>, <"var">, strtran( <value>, chr(10), "" ) )

   #xcommand try with <*x*> => begin sequence with <x>
   #xcommand try  => begin sequence with {|oErr| Break( oErr )}
   #xcommand catch [<!oErr!>] => recover [using <oErr>] <-oErr->
   #xcommand finally => always
   #xcommand endtry => end

   #define _CRLF chr( 13 ) + chr( 10 )
   #define _LF chr( 10 )

   //TOFIX use this for hdk version 2.1
   //#xtranslate tip_urlEncode( <x> ) => __tip_url_Encode( <x> )
   //#xtranslate tip_urlDecode( <x> [, <y> ] ) => __tip_url_Decode( <x> [, <y> ] )

   #define HISBDEFS

#endif

