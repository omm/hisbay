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
 * @(#)mvc.prg
 *
 * @author      Lorenzo Fiorini
 */

class Controller

   method init constructor

   method loadModel

   method view
   method redirect
   method sendHtml
   method sendJson

endclass

method init() class Controller

   return this

method loadModel( cModel ) class Controller

   return _Server:getModule( TYPE_MODELS, lower( cModel ) )

method view() class Controller

   local var cBinFile

   cBinFile := _Server:cAppRoot + "views" + hb_osPathSeparator() + lower( ::className() ) + hb_osPathSeparator()  + _Action + ".html"

   if !file( cBinFile )
      _Response:Flush( 404, "Not found", "text/html", "404 File: " + cBinFile + " not found" )
   else
      _Response:Flush( 200, "OK", "text/html", memoread( cBinFile ) )
   endif

   return this

method sendHtml( xData ) class Controller

   _Response:Flush( 200, "OK", "text/html", xData )

   return this

method sendJson( xData ) class Controller

   _Response:Flush( 200, "OK", "application/json", hb_JsonEncode( xData ) )

   return this

method redirect( cUrl ) class Controller

   _Response:Redirect( cUrl )

   return this

class Model

   method init constructor

endclass

method init() class Model

   return this
