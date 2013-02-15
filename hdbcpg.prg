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
 * @(#)hdbcpg.prg
 *
 * Hdbc Postgresql classes
 *
 * @author      Lorenzo Fiorini
 *
 */

#include "postgres.ch"

class HdbcPgConnection

   protected:

   var pDb
   var lTrans
   var lTrace init false
   var pTrace

   exported:

   method init constructor
   method close

   method startTransaction
   method getTransactionStatus
   method commit
   method rollback

   method createStatement
   method prepareStatement

   method getMetadata

endclass

method init( cHost, cDatabase, cUser, cPass, nPort ) class HdbcPgConnection

   defaultNil( nPort, 5432 )

   ::pDB := PQconnectDB( "dbname = " + cDatabase + " host = " + cHost + " user = " + cUser + " password = " + cPass + " port = " + hb_ntos( nPort ) )

   if PQstatus( ::pDb ) != CONNECTION_OK
      raiseError( PQerrormessage( ::pDb ) )
   endif

   return this

method close() class HdbcPgConnection

   PQFinish( ::pDb )

   return nil

method startTransaction() class HdbcPgConnection

   local var pRes    := PQexec( ::pDB, "BEGIN" )

   if PQresultstatus( pRes ) != PGRES_COMMAND_OK
      raiseError( PQresultErrormessage( pRes ) )
   endif

   PQclear( pRes )

   return nil

method getTransactionStatus()

   return PQtransactionstatus( ::pDb )

method commit() class HdbcPgConnection

   local var pRes    := PQexec( ::pDB, "COMMIT" )

   if PQresultstatus( pRes ) != PGRES_COMMAND_OK
      raiseError( PQresultErrormessage( pRes ) )
   endif

   PQclear( pRes )

   return nil

method rollback() class HdbcPgConnection

   local var pRes := PQexec( ::pDB, "ROLLBACK" )

   if PQresultstatus( pRes ) != PGRES_COMMAND_OK
      raiseError( PQresultErrormessage( pRes ) )
   endif

   PQclear( pRes )

   return nil

method createStatement() class HdbcPgConnection

   return HdbcPgStatement():new( ::pDB )

method prepareStatement( cSql ) class HdbcPgConnection

   return HdbcPgPreparedStatement():new( ::pDB, cSql )

method getMetadata() class HdbcPgConnection

   return HdbcPgDatabaseMetaData():new( ::pDB )

create class HdbcPgStatement

   protected:

   var pDB
   var cSql
   var oRs

   exported:

   var pRes

   method init constructor
   method executeQuery
   method executeUpdate
   method close

endclass

method init( pDB, cSql ) class HdbcPgStatement

   ::pDB      := pDB
   ::cSql     := cSql

   return this

method executeQuery( cSql ) class HdbcPgStatement

   ::pRes := PQexec( ::pDB, cSql )

   if PQresultstatus( ::pRes ) != PGRES_TUPLES_OK
      raiseError( PQresultErrormessage( ::pRes ) )
   else
      ::oRs := HdbcPgResultSet():new( ::pDB, this )
   endif

   return ::oRs

method executeUpdate( cSql ) class HdbcPgStatement

   local var nRows

   ::pRes := PQexec( ::pDB, cSql )

   if PQresultstatus( ::pRes ) != PGRES_COMMAND_OK
      raiseError( PQresultErrormessage( ::pRes ) )
   else
      nRows  := val( PQcmdTuples( ::pRes ) )
   endif

   return nRows

method close() class HdbcPgStatement

   if !( ::pRes == nil )

      PQclear( ::pRes )

      ::pRes := nil

   endif

   return nil

create class HdbcPgPreparedStatement

   protected:

   var pDB
   var cSql
   var pRes
   var oRs
   var cName init "hdbcpg11"

   var lPrepared init false
   var nParams init 0
   var aParams init array( 128 )

   exported:

   method init constructor
   method executeQuery
   method executeUpdate
   method close

   method setString( nParam, xValue )
   method SetNumber( n, x )   inline ::setString( n, str( x ) )
   method SetDate( n, x )     inline ::setString( n, dtos( x ) )
   method SetBoolean( n, x )  inline ::setString( n, iif( x, "t", "f" ) )

endclass

method init( pDB, cSql ) class HdbcPgPreparedStatement

   ::pDB      := pDB
   ::cSql     := cSql

   return this

method executeQuery() class HdbcPgPreparedStatement

   local var pRes

   if !::lPrepared
      ::aParams := asize( ::aParams, ::nParams )
      pRes := PQprepare( ::pDB, ::cName, ::cSql, ::nParams )
      if PQresultstatus( pRes ) != PGRES_COMMAND_OK
         raiseError( PQresultErrormessage( pRes ) )
      else
         ::lPrepared := true
      endif
      PQClear( pRes )
   else
      ::pRes := PQexecPrepared( ::pDB, ::cName, ::aParams )
      if PQresultstatus( ::pRes ) != PGRES_COMMAND_OK .and. PQresultstatus( ::pRes ) != PGRES_TUPLES_OK
         raiseError( PQresultErrormessage( ::pRes ) )
      else
         ::oRs := HdbcPgResultSet():new( ::pDB, this )
         ::aParams := array( ::nParams )
      endif
   endif

   return ::oRs

method executeUpdate() class HdbcPgPreparedStatement

   local var nRows

   if !::lPrepared
      ::aParams := asize( ::aParams, ::nParams )
      ::pRes := PQprepare( ::pDB, ::cName, ::cSql, ::nParams )
      if PQresultstatus( ::pRes ) != PGRES_COMMAND_OK
         raiseError( PQresultErrormessage( ::pRes ) )
      else
         ::lPrepared := true
      endif
      PQClear( ::pRes )
   else
      ::pRes := PQexecPrepared( ::pDB, ::cName, ::aParams )
      if PQresultstatus( ::pRes ) != PGRES_COMMAND_OK
         raiseError( PQresultErrormessage( ::pRes ) )
      else
         nRows  := val( PQcmdTuples( ::pRes ) )
         ::aParams := array( ::nParams )
      endif
   endif

   return nRows

method setString( nParam, xValue ) class HdbcPgPreparedStatement

   ::aParams[ nParam ] := xValue

   if !::lPrepared
      if nParam > ::nParams
         ::nParams := nParam
      endif
   endif

   return nil

method Close() class HdbcPgPreparedStatement

   if !( ::pRes == nil )

      PQclear( ::pRes )

   endif

   PQexec( ::pDB, "DEALLOCATE " + ::cName )

   return nil

create class HdbcPgResultSet

   protected:

   var pDB
   var pStmt
   var pRes

   var lBeforeFirst init true
   var lAfterLast init false

   var nRow init 0

   var cTableName
   var aPrimaryKeys
   var cPrimaryWhere
   var aBuffer
   var nCurrentRow

   exported:

   var      nRows init 0

   method   init
   method   close

   method   beforeFirst
   method   afterLast
   method   relative
   method   absolute

   method   first()            inline ::absolute( 1 )
   method   previous()         inline ::relative( -1 )
   method   next()             inline ::relative( 1 )
   method   last()             inline ::absolute( ::nRows )

   method   isBeforeFirst()    inline ::lBeforeFirst
   method   isFirst()          inline ( ::nRow == 1 )
   method   isLast()           inline ( ::nRow == ::nRows )
   method   isAfterLast()      inline ::lAfterLast
   method   getRow()           inline ::nRow

   method   findColumn
   method   getString

   method   getNumber( nField ) inline val( ::getString( nField ) )
   method   getDate( nField )   inline StoD( strtran( ::getString( nField ), "-" ) )
   method   getBoolean( nField ) inline ( ::getString( nField ) == "t" )

   method   getMetaData

   method   setTableName( cTable ) inline ::cTableName := cTable
   method   setPrimaryKeys( aKeys ) inline ::aPrimaryKeys := aKeys

   method   moveToInsertRow
   method   moveToCurrentRow
   method   insertRow
   method   updateRow
   method   deleteRow
   method   updateBuffer

   method   updateString( nField, cValue ) inline ::updateBuffer( nField, cValue, "C" )
   method   updateNumber( nField, nValue ) inline ::updateBuffer( nField, hb_ntos( nValue ), "N" )
   method   updateDate( nField, dValue ) inline ::updateBuffer( nField, dtos( dValue ), "D" )
   method   updateBoolean( nField, lValue ) inline ::updateBuffer( nField, iif( lValue, "t", "f" ), "L" )

endclass

method init( pDB, pStmt ) class HdbcPgResultSet

   ::pDB      := pDB
   ::pStmt    := pStmt
   ::pRes     := pStmt:pRes

   ::nRows := PQlastrec( ::pRes )

   if ::nRows != 0
      ::nRow := 0
      ::lBeforeFirst := true
      ::lAfterLast := false
   endif

   return this

method Close() class HdbcPgResultSet

   return nil

method beforeFirst() class HdbcPgResultSet

   ::nRow := 0
   ::lBeforeFirst := true
   ::lAfterLast := false

   return nil

method afterLast() class HdbcPgResultSet

   ::nRow := ::nRows + 1
   ::lBeforeFirst := false
   ::lAfterLast := true

   return nil

method relative( nMove ) class HdbcPgResultSet

   local var nRowNew := ::nRow + nMove

   if nRowNew >= 1 .and. nRowNew <= ::nRows

      ::nRow := nRowNew
      ::lBeforeFirst := false
      ::lAfterLast := false

      return true

   else

      if nRowNew < 1
         ::nRow := 0
         ::lBeforeFirst := true
      else
         ::nRow := ::nRows + 1
         ::lAfterLast := true
      endif

   endif

   return false

method absolute( nMove ) class HdbcPgResultSet

   if nMove > 0
      if nMove <= ::nRows
         ::nRow := nMove
         ::lBeforeFirst := false
         ::lAfterLast := false
         return true
       endif
   elseif nMove < 0
      if -nMove <= ::nRows
         ::nRow := ::nRows + nMove
         ::lBeforeFirst := false
         ::lAfterLast := false
         return true
       endif
   endif

   return false

method findColumn( cField ) class HdbcPgResultSet

   return PQFNumber( ::pRes, cField )

method getString( nField ) class HdbcPgResultSet

   if HB_ISCHAR( nField )
      nField := PQFNumber( ::pRes, nField )
   endif

   return PQgetvalue( ::pRes, ::nRow, nField )

method getMetaData() class HdbcPgResultSet

   return HdbcPgResultSetMetaData():new( ::pRes )

method moveToInsertRow() class HdbcPgResultSet

   ::nCurrentRow := ::nRow

   ::aBuffer := array( PQnfields( ::pRes ) )

   return nil

method moveToCurrentRow() class HdbcPgResultSet

   ::nRow := ::nCurrentRow

   return nil

method updateBuffer( nField, xValue, cType ) class HdbcPgResultSet

   if HB_ISCHAR( nField )
      nField := ::findColumn( nField )
   endif

   if ::aBuffer == nil
      ::aBuffer := array( PQnfields( ::pRes ) )
   endif

   ::aBuffer[ nField ] := { xValue, cType }

   return nil

method insertRow() class HdbcPgResultSet

   local var pRes := ::pRes
   local var aBuffer := ::aBuffer
   local var cSqlFields
   local var cSqlValues
   local var nField

   local var nFields := len( aBuffer )

   if !empty( ::cTableName )
      cSqlFields := ""
      cSqlValues := ""
      for nField := 1 to nFields
         if aBuffer[ nField ] != nil
            cSqlFields += "," + PQfname( pRes, nField )
            cSqlValues += "," + iif( aBuffer[ nField ][ 2 ] == "N", aBuffer[ nField ][ 1 ], "'" + aBuffer[ nField ][ 1 ] + "'" )
         endif
      next

      pRes := PQexec( ::pDB, "INSERT INTO " + ::cTableName + " (" + substr( cSqlFields, 2 ) + ") VALUES (" + substr( cSqlValues, 2 ) + ")" )

      if PQresultstatus( pRes ) != PGRES_COMMAND_OK
         raiseError( PQresultErrormessage( pRes ) )
      endif

      PQclear( pRes )

   else

      raiseError( "Table name is not set" )

   endif

   ::aBuffer := nil

   return nil

method updateRow() class HdbcPgResultSet

   local var pRes := ::pRes
   local var aBuffer := ::aBuffer
   local var aKeys := ::aPrimaryKeys
   local var nKeys := len( aKeys )
   local var cSql
   local var cSqlWhere
   local var nField
   local var nFields := len( aBuffer )

   if !empty( ::cTableName ) .and. !empty( aKeys )
      cSql := ""
      for nField := 1 to nFields
         if aBuffer[ nField ] != nil
            cSql += "," + PQfname( pRes, nField ) + "=" + iif( aBuffer[ nField ][ 2 ] == "N", aBuffer[ nField ][ 1 ], "'" + aBuffer[ nField ][ 1 ] + "'" )
         endif
      next

      cSqlWhere := ""

      for nField := 1 to nKeys
         cSqlWhere += "AND " + aKeys[ nField ][ 1 ] + "=" + iif( aKeys[ nField ][ 2 ] == "N", ::getString( aKeys[ nField ][ 1 ] ), "'" + ::getString( aKeys[ nField ][ 1 ] ) + "'" )
      next

      pRes := PQexec( ::pDB, "UPDATE " + ::cTableName + " SET " + substr( cSql, 2 ) + " WHERE " + substr( cSqlWhere, 5 ) )

      if PQresultstatus( pRes ) != PGRES_COMMAND_OK
         raiseError( PQresultErrormessage( pRes ) )
      endif

      PQclear( pRes )

   endif

   return nil

method deleteRow() class HdbcPgResultSet

   local var pRes
   local var aKeys := ::aPrimaryKeys
   local var nField
   local var nKeys := len( aKeys )
   local var cSqlWhere

   if !empty( ::cTableName ) .and. !empty( aKeys )

      cSqlWhere := ""

      for nField := 1 to nKeys
         cSqlWhere += "AND " + aKeys[ nField ][ 1 ] + "=" + iif( aKeys[ nField ][ 2 ] == "N", ::getString( aKeys[ nField ][ 1 ] ), "'" + ::getString( aKeys[ nField ][ 1 ] ) + "'" )
      next

      pRes := PQexec( ::pDB, "DELETE FROM " + ::cTableName + " WHERE " + substr( cSqlWhere, 5 ) )

      if PQresultstatus( pRes ) != PGRES_COMMAND_OK
         raiseError( PQresultErrormessage( pRes ) )
      endif

      PQclear( pRes )

   endif

   return nil

create class HdbcPgResultSetMetaData

   protected:

   var pRes

   exported:

   method init constructor
   method getColumnCount
   method getColumnName
   method getColumnDisplaySize

endclass

method init( pRes ) class HdbcPgResultSetMetaData

   ::pRes := pRes

   return this

method getColumnCount() class HdbcPgResultSetMetaData

   return PQnfields( ::pRes )

method getColumnName( nColumn ) class HdbcPgResultSetMetaData

   return PQfname( ::pRes, nColumn )

method getColumnDisplaySize( nColumn ) class HdbcPgResultSetMetaData

   return PQfsize( ::pRes, nColumn )

create class HdbcPgDatabaseMetaData

   protected:

   var pDB

   exported:

   method init constructor
   method getTables
   method getPrimaryKeys

endclass

method init( pDB ) class HdbcPgDatabaseMetaData

   ::pDB := pDB

   return this

method getTables( cCatalog, cSchema, cTableName, cTableType ) class HdbcPgDatabaseMetaData

   local var n, nTables
   local var aTables := {}
   local var cSql
   local var pRes

   defaultNil( cCatalog, "" )
   defaultNil( cSchema, "public" )
   defaultNil( cTableName, "%" )
   defaultNil( cTableType, "BASE TABLE" )

   cSql := "select table_catalog, table_schema, table_name, table_type from information_schema.tables "
   cSql += "where table_schema in ('" + cSchema + "') and table_schema not in ('pg_catalog', 'information_schema')"
   cSql += " and table_name ilike '" + cTableName + "'"
   cSql += " and table_type in ('" + cTableType + "')"

   pRes := PQexec( ::pDB, cSql )

   if PQresultstatus( pRes ) != PGRES_TUPLES_OK
      raiseError( PQresultErrormessage( pRes ) )
   else
      nTables := PQlastrec( pRes )
      for n := 1 to nTables
         aadd( aTables, { PQgetvalue( pRes, n, 1 ), PQgetvalue( pRes, n, 2 ), PQgetvalue( pRes, n, 3 ), PQgetvalue( pRes, n, 4 ), "" } )
      next
   endif

   PQclear( pRes )

   return aTables

method getPrimaryKeys( cCatalog, cSchema, cTableName ) class HdbcPgDatabaseMetaData

   local var pRes
   local var cQuery
   local var nKeys
   local var aKeys
   local var n

   defaultNil( cCatalog, "" )
   defaultNil( cSchema, "public" )

   cQuery := "SELECT c.attname "
   cQuery += "  FROM pg_class a, pg_class b, pg_attribute c, pg_index d, pg_namespace e "
   cQuery += " WHERE a.oid = d.indrelid "
   cQuery += "   AND a.relname = '" + cTableName + "'"
   cQuery += "   AND b.oid = d.indexrelid "
   cQuery += "   AND c.attrelid = b.oid "
   cQuery += "   AND d.indisprimary "
   cQuery += "   AND e.oid = a.relnamespace "
   cQuery += "   AND e.nspname = '" + cSchema + "'"

   pRes := PQexec( ::pDB, cQuery )

   nKeys := PQlastrec( pRes )

   if PQresultstatus( pRes ) == PGRES_TUPLES_OK .and. nKeys != 0

       aKeys := {}

       for n := 1 To nKeys
          aadd( aKeys, PQgetvalue( pRes, n, 1 ) )
       next

   endif

   PQclear( pRes )

   return aKeys

static procedure raiseError( cErrMsg )

   local var oErr

   oErr := ErrorNew()
   oErr:severity    := ES_ERROR
   oErr:genCode     := EG_OPEN
   oErr:subSystem   := "HDBCPG"
   oErr:SubCode     := 1000
   oErr:Description := cErrMsg

   Eval( ErrorBlock(), oErr )

   return
