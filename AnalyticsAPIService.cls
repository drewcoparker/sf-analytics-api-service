/**
 * @author Drew Parker
 * @date 04/27/2020
 *
 * @description Service class used for interfacing with the Analytics REST API
 */
public with sharing class AnalyticsAPIService {
  /**
   * Gets an Analytics REST API http response body given an endpoint path.
   * Make sure the org's base url is captured in Remote Sites.
   * @param  {String} path i.e., '/wave/datasets/<datasetId>'
   * @return the http response body
   */
  public static String getApiResponseBody(String path) {
    try {
      Http http = new Http();
      HttpRequest httpReq = new HttpRequest();
      HttpResponse httpRes = new HttpResponse();
      
      httpReq.setMethod('GET');
      httpReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
      httpReq.setEndpoint(URL.getSalesforceBaseUrl().toExternalForm() + path);
      httpRes = http.send(httpReq);

      return httpRes.getBody();

    } catch (Exception e) {
      throw new AnalyticsAPIServiceException(e.getMessage());
    }
  }
  
  /**
   * Gets the dataset Ids for all of the org's datasets.
   * https://developer.salesforce.com/docs/atlas.en-us.bi_dev_guide_rest.meta/bi_dev_guide_rest/bi_resources_datasets.htm
   * @return List<String> a List of dataset Ids
   */
  public static List<String> getDatasetIds() {
    try {
      String resBody = getApiResponseBody('/services/data/v48.0/wave/datasets');
      List<String> datasetIds = new List<String>();
      String nextPageUrl = '';

      do {
        Map<String, Object> bodyMap = (Map<String, Object>)JSON.deserializeUntyped(resBody);

        List<Map<String, Object>> mapCollection = new List<Map<String, Object>>();

        // Loop through the deserialized response and a the dataset obj to the collection
        List<Object> datasets = (List<Object>)bodyMap.get('datasets');
        for (Object dataset : datasets) {
          mapCollection.add((Map<String, Object>)dataset);
        }

        // Get the Ids from each dataset object
        for (Map<String, Object> datasetMap : mapCollection) {
          datasetIds.add((String)datasetMap.get('id'));
        }

        // Update the path to nextPageUrl and make the request to get a new response
        nextPageUrl = (String)bodyMap.get('nextPageUrl');
        if (nextPageUrl != null) {
          resBody = getApiResponseBody(nextPageUrl);
        }

      // Continue to make a new request as long as nextPageUrl is not null
      } while (nextPageUrl != null);

      return datasetIds;
        
    } catch (Exception e) {
      throw new AnalyticsAPIServiceException(e.getMessage());
    }
  }

  /**
   * Gets the total rows used within each dataset in the org
   * https://developer.salesforce.com/docs/atlas.en-us.bi_dev_guide_rest.meta/bi_dev_guide_rest/bi_resources_datasets_id_versions.htm
   * @return Integer the total number of dataset rows
   */
  public static Integer getTotalDataSetRows() {
    try {
      Integer totalRows = 0;
      List<String> dataSetIds = getDatasetIds();

      // Loop, deserialize, and extract the totalRows within each dataset
      for (String dsId : dataSetIds) {
        String resBody = getApiResponseBody('/services/data/v48.0/wave/datasets/' + dsId + '/versions/');
        Map<String, Object> resBodyMap = (Map<String, Object>)JSON.deserializeUntyped(resBody);

        List<Object> versions = (List<Object>)resBodyMap.get('versions');
        List<Map<String, Object>> versionCollection = new List<Map<String, Object>>();
        
        for (Object version : versions) {
          versionCollection.add((Map<String, Object>)version);
        }
        
        for (Map<String, Object> versionMap : versionCollection) {
          totalRows += (Integer)versionMap.get('totalRows');
        }
      }
      return totalRows;

    } catch (Exception e) {
      throw new AnalyticsAPIServiceException(e.getMessage());
    }
  }

  /**
   * Gets the total rows allotted by the EA license level
   * @return Long the total number of dataset rows allotted
   */
  public static Long getTotalRowStorage() {
    try {
      Long totalRowsAllotted = 0;
      Boolean isEALicense = false;

      List<PermissionSetLicense> eaLics = [ 
        SELECT 
          MasterLabel,
          UsedLicenses,
          TotalLicenses,
          Status
        FROM 
          PermissionSetLicense
        WHERE
          MasterLabel LIKE 'Einstein%'
      ];

      for (PermissionSetLicense eaLic : eaLics) {
        if (eaLic.MasterLabel == 'Einstein Analytics Plus' && eaLic.Status == 'Active') {
          totalRowsAllotted += 10000000000L;
          isEALicense = true;

        } else if (eaLic.MasterLabel == 'Einstein Analytics Growth' && eaLic.Status == 'Active') {
          totalRowsAllotted += 100000000L;
          isEALicense = true;
        }
      }

      List<PermissionSetLicense> allLics = [
        SELECT 
          MasterLabel, 
          UsedLicenses, 
          TotalLicenses, 
          Status
        FROM 
          PermissionSetLicense
      ];

      for (PermissionSetLicense lic : allLics) {
        if (lic.MasterLabel.contains('Einstein Analytics for Financial Services Cloud') && lic.Status == 'Active') {
          totalRowsAllotted += 25000000;

        } else if (lic.MasterLabel.contains('Einstein Analytics for Health Cloud') && lic.Status == 'Active') {
          totalRowsAllotted += 25000000;

        } else if (lic.MasterLabel.contains('Event Monitoring') && lic.Status == 'Active') {
          totalRowsAllotted += 50000000;

        } else if (lic.MasterLabel.contains('B2B Marketing') && lic.Status == 'Active') {
          totalRowsAllotted += 25000000;

        } else if (lic.MasterLabel.contains('Additional Data Rows') && lic.Status == 'Active') {
          totalRowsAllotted += lic.TotalLicenses * 100000000;
          
        // The Einstein Analytics Plus and Einstein Analytics Growth license already includes 1 Sales Analytics and 
        // 1 Service Analytics license, so your total row allocation remains 10 billion
        } else if (lic.MasterLabel.contains('Sales Analytics') && lic.Status == 'Active') {
          if (lic.TotalLicenses > 1 && isEALicense == true) {
            totalRowsAllotted += (lic.TotalLicenses - 1) * 25000000;
          } else {
            totalRowsAllotted += lic.TotalLicenses * 25000000;
          }
          
        // The Einstein Analytics Plus and Einstein Analytics Growth license already includes 1 Sales Analytics and 
        // 1 Service Analytics license, so your total row allocation remains 10 billion
        } else if (lic.MasterLabel.contains('Service Analytics') && lic.Status == 'Active') {
          if (lic.TotalLicenses > 1 && isEALicense == true) {
              totalRowsAllotted += (lic.TotalLicenses - 1) * 25000000;
          } else {
            totalRowsAllotted += lic.TotalLicenses * 25000000;
          }
        }
      }
      return totalRowsAllotted;

    } catch (Exception e) {
      throw new AnalyticsAPIServiceException(e.getMessage());
    }
  }

  /**
   * Gets the remaining storage of dataset rows
   * @return Long the total unused dataset rows
   */
  public static Long getRemainingStorage() {
    try {
      Long unusedRows = 0;
      Long totalRowStorage = getTotalRowStorage();
      Long usedRows = getTotalDataSetRows();

      if (totalRowStorage > usedRows) {
        unusedRows = totalRowStorage - usedRows;
      }

      return unusedRows;

    } catch (Exception e) {
      throw new AnalyticsAPIServiceException(e.getMessage());
    }
  }

  public class AnalyticsAPIServiceException extends Exception {}
}
