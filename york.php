<?php
// Created by Xuan Wang
// Layar Technical Support
// Email: xuan@layar.com
// Website: http://layar.com

// Copyright (c) 2011, Layar B.V.
// All rights reserved.

// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//    * Neither the name of the <organization> nor the
//      names of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL LAYAR B.V BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require_once('york-config.inc.php');

/*** Specific Custom Functions ***/

// Put needed getPOI request parameters and their values in an associative array
//
// Arguments:
//  array ; An array of needed parameters passed in getPOI request
//
// Returns:
//  array ; An associative array which contains the request parameters and
//  their values.
function getRequestParams($keys) {

  $paramsArray = array();
  try {
    // Retrieve parameter values using $_GET and put them in $value array with
    // parameter name as key. 
    foreach( $keys as $key ) {
      if ( isset($_GET[$key]) )
        $paramsArray[$key] = $_GET[$key]; 
      else 
        throw new Exception($key .' parameter is not passed in GetPOI request.');
    }
    return $paramsArray;
  }
  catch(Exception $e) {
    echo 'Message: ' .$e->getMessage();
  }
}//getRequestParams 

// Connect to the database, configuration information is stored in
// config.inc.php file
function connectDb() {
  try {
    $dbconn = 'mysql:host=' . DBHOST . ';dbname=' . DBDATA ; 
    $db = new PDO($dbconn , DBUSER , DBPASS , array(PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8'));
    // set the error mode to exceptions
    $db->setAttribute(PDO::ATTR_ERRMODE , PDO::ERRMODE_EXCEPTION);
     return $db; 
  }// try
  catch(PDOException $e) {
    error_log('message:' . $e->getMessage());
  }// catch
}// connectDb

// Change a string value to float
//
// Arguments:
//   string ; A string value.
// 
// Returns:
//   float ; If the string is empty, return NULL.
//
function changetoFloat($string) {
  if (strlen(trim($string)) != 0) 
    return (float)$string;
  return NULL;
}//changetoFloat

// Change a string value to integer. 
//
// Arguments:
//   string ; A string value.
// 
// Returns:
//   Int ; If the string is empty, return NULL.
//
function changetoInt($string) {
  if (strlen(trim($string)) != 0) 
    return (int)$string;
  return NULL;
}//changetoInt

// Convert a string into an array.
//
// Arguments:
//  string ; The input string
//  separater, string ; The boundary string used to separate the input string
//
// Returns:
//  array ; An array of strings. Otherwise, return an empty array. 
function changetoArray($string, $separator){
  $newArray = array();
  if($string) {
    if (substr_count($string,$separator)) {
      $newArray= array_map('trim' , explode($separator, $string));
        }//if
    else 
      $newArray[0] = trim($string);
  }
  return $newArray;
}//changetoArray

// Convert a TinyInt value to a boolean value TRUE or FALSE
//
// Arguments: 
//  int  value_Tinyint ; The Tinyint value (0 or 1) of a key in the database. 
//
// Returns:
//   boolean ; The boolean value, return 'TRUE' when Tinyint is 1. Return
//     'FALSE' when Tinyint is 0.
//
function changetoBool($value_Tinyint) {
  if (strlen(trim($value_Tinyint)) != 0) {
    if ($value_Tinyint == 0)
      return FALSE;
    else 
      return TRUE;
   }
  return NULL;
}//changetoBool

// Put fetched actions for each POI into an associative array.
//
// Arguments:
//   db ; The database connection handler. 
//   poi ; The POI array.
//
// Returns:
//   array ; An associative array of received actions for this POI.Otherwise,
//   return an empty array. 
// 
function getPoiActions($db , $poi) {
  // Define an empty $actionArray array. 
  $actionArray = array();

  // A new table called 'POIAction' is created to store actions, each action
  // has a field called 'poiID' which shows the POI id that this action belongs
  // to. 
  // The SQL statement returns actions which have the same poiID as the id of
  // the POI($poiID).
  $sql_actions = $db->prepare(' 
      SELECT label, 
             uri, 
             contentType,
             activityType,
             autoTriggerRange,
             autoTriggerOnly,
             params
      FROM POIAction
      WHERE poiID = :id '); 

  // Binds the named parameter marker ':id' to the specified parameter value
  // '$poiID.                 
  $sql_actions->bindParam(':id', $poi['id'], PDO::PARAM_STR);
  // Use PDO::execute() to execute the prepared statement $sql_actions. 
  $sql_actions->execute();
  // Iterator for the $actionArray array.
  $count = 0; 
  // Fetch all the poi actions. 
  $actions = $sql_actions->fetchAll(PDO::FETCH_ASSOC);

  /* Process the $actions result */
  // if $actions array is not empty. 
  if ($actions) {
    // Put each action information into $actionArray array.
    foreach ($actions as $action) { 
      // Change 'activityType' to Integer.
      $action['activityType'] = changetoInt($action['activityType']);
      $action['autoTriggerRange'] = changetoInt($action['autoTriggerRange']);
      $action['autoTriggerOnly'] = changetoBool($action['autoTriggerOnly']);
      $action['params'] = changetoArray($action['params'] , ',');
      // Assign each action to $actionArray array. 
      $actionArray[$count] = $action;
      $count++; 
    }// foreach
  }//if
  return $actionArray;
}//getPoiActions

// Put fetched icon dictionary for each POI into an associative array.
// 
// Arguments:
//  db ; The database connection handler.
//  iconID, integer ; The iconID value  which is stored in this POI.
//
// Return:
//  array ; An associative array of retrieved icon dictionary for this POI.
//  Otherwise, return NULL. 
function getIcon($db, $iconID) {
  // If no icon object is found, return NULL.
  $icon = NULL;
  
  // Run the query to retrieve icon information for this POI.  
  $sql_icon = $db->prepare( '
            SELECT url, type
              FROM Icon
             WHERE id = :iconID  
            ' );
  $sql_icon->bindParam(':iconID', $iconID, PDO::PARAM_INT);
  $sql_icon->execute();
  $rawIcon = $sql_icon->fetch(PDO::FETCH_ASSOC);

  // Assign returned values to $icon array. 
  if($rawIcon){
    $rawIcon['type'] = changetoInt($rawIcon['type']);
    $icon = $rawIcon;
  }    
  return $icon;
}//getIcon

// Put fetched object parameters for each POI into an associative array.
//
// Arguments:
//   db ; The database connection handler. 
//   objectID, integer ; The object id assigned to this POI.
//
// Returns:
//   associative array or NULL ; An array of received object related parameters for this POI. otherwise, return NULL. 
// 
function getObject($db , $objectID) {
  // If no object object is found, return NULL. 
  $object = NULL;

  // A new table called 'Object' is created to store object related parameters,
  // namely 'url', 'contentType', 'reducedURL' and 'size'. The SQL statement
  // returns object which has the same id as $objectID stored in this POI. 
  $sql_object = $db->prepare(
    ' SELECT contentType,
             url, 
             reducedURL, 
             size 
      FROM Object
      WHERE id = :objectID 
      LIMIT 0,1 '); 

  // Binds the named parameter marker ':objectID' to the specified parameter
  // value $objectID.                 
  $sql_object->bindParam(':objectID', $objectID, PDO::PARAM_INT);
  // Use PDO::execute() to execute the prepared statement $sql_object. 
  $sql_object->execute();
  // Fetch the poi object. 
  $rawObject = $sql_object->fetch(PDO::FETCH_ASSOC);

  /* Process the $rawObject result */
  // if $rawObject array is not empty. 
  if ($rawObject) {
    // Change 'size' type to float. 
    $rawObject['size'] = changetoFloat($rawObject['size']);
    $object = $rawObject;
  }
  return $object;
}//getObject


// Put fetched transform related parameters for each POI into an associative
// array. The returned values are assigned to $poi[transform].
//
// Arguments:
//   db ; The database connection handler. 
//   transformID , integer ; The transform id which is assigned to this POI.
//
// Returns: associative array or NULL; An array of received transform related
// parameters for this POI. Otherwise, return NULL. 
// 
function getTransform($db , $transformID) {
  // If no transform object is found, return NULL. 
  $transform = NULL;
  // A new table called 'Transform' is created to store transform related
  // parameters, namely 'rotate','translate' and 'scale'. 
  // 'transformID' is the transform that is applied to this POI. 
  // The SQL statement returns transform which has the same id as the
  // $transformID of this POI. 
  $sql_transform = $db->prepare('
      SELECT rel, 
             angle, 
             rotate_x,
             rotate_y,
             rotate_z,
             translate_x,
             translate_y,
             translate_z,
             scale
      FROM Transform
      WHERE id = :transformID 
      LIMIT 0,1 '); 

  // Binds the named parameter marker ':transformID' to the specified parameter
  // value $transformID                
  $sql_transform->bindParam(':transformID', $transformID, PDO::PARAM_INT);
  // Use PDO::execute() to execute the prepared statement $sql_transform. 
  $sql_transform->execute();
  // Fetch the poi transform. 
  $rawTransform = $sql_transform->fetch(PDO::FETCH_ASSOC);

  /* Process the $rawTransform result */
  // if $rawTransform array is not  empty 
  if ($rawTransform) {
    // Change the value of 'scale' into decimal value.
    $transform['scale'] = changetoFloat($rawTransform['scale']);
    // organize translate field
    $transform['translate']['x'] =changetoFloat($rawTransform['translate_x']);
    $transform['translate']['y'] = changetoFloat($rawTransform['translate_y']);
    $transform['translate']['z'] = changetoFloat($rawTransform['translate_z']);
    // organize rotate field
    $transform['rotate']['axis']['x'] = changetoFloat($rawTransform['rotate_x']);
    $transform['rotate']['axis']['y'] = changetoFloat($rawTransform['rotate_y']);
    $transform['rotate']['axis']['z'] = changetoFloat($rawTransform['rotate_z']);
    $transform['rotate']['angle'] = changetoFloat($rawTransform['angle']);
    $transform['rotate']['rel'] = changetoBool($rawTransform['rel']);
  }//if 
    
  return $transform;
}//getTransform
// Put received POIs into an associative array. The returned values are
// assigned to $reponse['hotspots'].
//
// Arguments:
//   db ; The handler of the database.
//   value , array ; An array which contains all the needed parameters
//   retrieved from GetPOI request. 
//
// Returns:
//   array ; An array of received POIs.
//
function getHotspots( $db, $value ) {
  // Define an empty $hotspots array.
  $hotspots = array();
/* Create the SQL query to retrieve POIs within the 'radius' returned from
   GetPOI request. 
   The first 50 returned POIs are selected.
   The distance is caculated based on the Haversine formula.  Note: this
   way of calculation is not scalable for querying large database.
*/
	
  // Use PDO::prepare() to prepare SQL statement. This statement is used due to
  // security reasons and will help prevent general SQL injection attacks.
  // ':lat1', ':lat2', ':long' and ':radius' are named parameter markers for
  // which real values will be substituted when the statement is executed.
  // $sql is returned as a PDO statement object. 
  $sql = $db->prepare( '
  			SELECT id,
               imageURL,
               title,
               description,
               footnote,
               lat,
               lon,
               (((acos(sin((:lat1 * pi() / 180)) * sin((lat * pi() / 180)) +
                  	  cos((:lat2 * pi() / 180)) * cos((lat * pi() / 180)) * 
                      cos((:long  - lon) * pi() / 180))
                      ) * 180 / pi()
               )* 60 * 1.1515 * 1.609344 * 1000
               ) as distance,
               iconID,
               objectID,
               transformID
  			  FROM POI
         WHERE POI.poiType = "geo"   
        HAVING distance < :radius
      ORDER BY distance ASC
         ' );

  // PDOStatement::bindParam() binds the named parameter markers to the
  // specified parameter values. 
  $sql->bindParam( ':lat1', $value['lat'], PDO::PARAM_STR );
  $sql->bindParam( ':lat2', $value['lat'], PDO::PARAM_STR );
  $sql->bindParam( ':long', $value['lon'], PDO::PARAM_STR );
  $sql->bindParam( ':radius', $value['radius'], PDO::PARAM_INT );
  // Use PDO::execute() to execute the prepared statement $sql. 
  $sql->execute();
  // Iterator for the response array.
  $i = 0; 
  // Use fetchAll to return an array containing all of the remaining rows in
  // the result set.
  // Use PDO::FETCH_ASSOC to fetch $sql query results and return each row as an
  // array indexed by column name.
  $rawPois = $sql->fetchAll(PDO::FETCH_ASSOC);
 
  /* Process the $pois result */
  // if $rawPois array is not  empty 
  if ($rawPois) {
    // Put each POI information into $hotspots array.
 	  foreach ( $rawPois as $rawPoi ) {
 	  $poi = array();
      $poi['id'] = $rawPoi['id'];
      $poi['imageURL'] = $rawPoi['imageURL'];
      // Get anchor object information
      $poi['anchor']['geolocation']['lat'] = changetoFloat($rawPoi['lat']);
      $poi['anchor']['geolocation']['lon'] = changetoFloat($rawPoi['lon']);
      // get text object information
      $poi['text']['title'] = $rawPoi['title'];
      $poi['text']['description'] = $rawPoi['description'];
      $poi['text']['footnote'] = $rawPoi['footnote'];
      //User function getPOiActions() to return an array of actions associated
      //with the current POI
      $poi['actions'] = getPoiActions($db, $rawPoi);
      // Get object object information if iconID is not null
      if(count($rawPoi['iconID']) != 0) 
        $poi['icon'] = getIcon($db , $rawPoi['iconID']);
      // Get object object information if objectID is not null
      if(count($rawPoi['objectID']) != 0) 
        $poi['object'] = getObject($db, $rawPoi['objectID']);
      // Get transform object information if transformID is not null
      if(count($rawPoi['transformID']) != 0)
        $poi['transform'] = getTransform($db, $rawPoi['transformID']);
      // Put the poi into the $hotspots array.
      $hotspots[$i] = $poi;
      $i++;
    }//foreach
  }//if
  return $hotspots;
}//getHotspots

/*** Main entry point ***/

/* Put parameters from GetPOI request into an associative array named $requestParams */
// Put needed parameter names from GetPOI request in an array called $keys. 
$keys = array( 'layerName', 'lat', 'lon', 'radius' );

// Initialize an empty associative array.
$requestParams = array(); 
// Call funtion getRequestParams()  
$requestParams = getRequestParams($keys);
/* Connect to MySQL server. We use PDO which is a PHP extension to formalise database connection.
	 For more information regarding PDO, please see http://php.net/manual/en/book.pdo.php. 
 */	
// Connect to predefined MySQl database.  
$db = connectDb(); 
	
/* Construct the response into an associative array.*/
	
// Create an empty array named response.
$response = array();
	
// Assign cooresponding values to mandatory JSON response keys.
$response['layer'] = $requestParams['layerName'];
	
// Use Gethotspots() function to retrieve POIs with in the search range.  
$response['hotspots'] = getHotspots($db, $requestParams);

// if there is no POI found, return a custom error message.
if (!$response['hotspots'] ) {
	$response['errorCode'] = 20;
 	$response['errorString'] = 'No POI found. Please adjust the range.';
}//if
else {
  $response['errorCode'] = 0;
  $response['errorString'] = 'ok';
}//else
   
	/* All data is in $response, print it into JSON format.*/
	
	// Put the JSON representation of $response into $jsonresponse.
	$jsonresponse = json_encode( $response );
	
	// Declare the correct content type in HTTP response header.
	header( 'Content-type: application/json; charset=utf-8' );
	
	// Print out Json response.
	echo $jsonresponse;

?>
